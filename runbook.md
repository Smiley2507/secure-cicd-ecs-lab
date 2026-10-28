# Runbook — bring-up, gate tests, teardown

All commands run from WSL. AWS profile: `sandbox-user` (eu-west-1).

```bash
export AWS_PROFILE=sandbox-user
aws sts get-caller-identity          # expect account 904570587823
```

## 0. One-time: state bucket versioning

```bash
aws s3api put-bucket-versioning --bucket sandbox-state-bucket-001 \
    --versioning-configuration Status=Enabled
```

## 1. Infrastructure

```bash
cd terraform
terraform init
terraform plan -out tfplan
terraform apply tfplan
terraform output
```

SSH, Jenkins and SonarQube are opened to **your current public IP only**. Terraform
looks it up at plan time (`terraform output admin_cidr`). If your IP changes and the UIs stop loading, run
`terraform apply` again to move the rules. To allow a wider range instead, set
`admin_cidr = "x.x.x.x/24"` in `terraform.tfvars`.

On first apply the ECS service runs the **bootstrap** placeholder
(`weather-app-bootstrap` family), so `curl $(terraform output -raw app_url)/health`
returns `ok` before any pipeline has run.

## 2. Configure the CI host

```bash
cd ../ansible
source ~/ansible-venv/bin/activate
pip install -r requirements.txt          # ansible-core, boto3, botocore
ansible-galaxy collection install -r requirements.yml
ansible-inventory --graph            # expect secure-cicd-jenkins under @role_jenkins
ansible-playbook site.yml
```

The play prints the Jenkins unlock password and the SonarQube URL.

## 3. SonarQube (manual, once)

1. Open `sonarqube_url` and log in as `admin` / `admin`. Change the password when prompted.
2. **Quality gate:** *Quality Gates → Create* `Strict`, with these conditions on **Overall Code**:
   - Security Rating is worse than A
   - Reliability Rating is worse than A
   - Security Hotspots Reviewed is less than 100%

   Set it as **Default**. *Sonar way* only checks *new* code, which is empty on a project's first analysis.
3. **Token:** *My Account → Security → Generate Token*, type *Global Analysis Token*. Copy it.

## 4. Jenkins (manual, once)

1. Open `jenkins_url`, unlock it, and install the suggested plugins. Create the admin user.
2. **Credentials** (*Manage Jenkins → Credentials → System → Global*), both *Secret text*:

   | ID | Value |
   |---|---|
   | `sonar_token` | the SonarQube token from step 3 |
   | `snyk_token` | Snyk → *Account settings → Auth Token* |
3. **Job:** *New Item → Pipeline*, named `secure-cicd-ecs`. Set *Pipeline script from SCM* → Git → this repo, branch `*/main`, script path `Jenkinsfile`.

No AWS credentials go into Jenkins. The pipeline uses the instance role.

## 5. Gate tests (evidence)

| Test | How | Expected |
|---|---|---|
| Baseline | Build `main` | All stages green, new task def revision, `/health` returns the new tag |
| Vulnerable dependency | Branch `test/vuln-injection`: add `PyYAML==5.3.1` to `app/requirements.txt`, then point the job at that branch | **SCA (Snyk)** fails on CVE-2020-14343. ECS untouched. |
| Fix | Remove the line and build again | Green, new revision |
| Secret (optional) | Commit a file containing a fake AWS key pair | **Secret Scan** fails. Delete the branch afterwards so the key never reaches `main`. |

Check that ECS really was untouched by a failed build:

```bash
aws ecs describe-services --cluster secure-cicd-cluster --services weather-app \
    --query 'services[0].[taskDefinition,deployments[0].rolloutState]'
```

## 6. Evidence to collect

- Jenkins stage view: failed (vuln) and green (fix) builds
- Archived `reports/` from both builds: gitleaks, sonar, snyk, sbom, trivy, zap, taskdef, ecs
- `aws ecs describe-services` events showing the deployment
- `aws ecs list-task-definitions --family-prefix weather-app --status INACTIVE` (cleanup)
- `aws ecr describe-images --repository-name weather-app` and `aws ecr get-lifecycle-policy --repository-name weather-app`
- CloudWatch Logs `/ecs/weather-app` and the three alarms in `OK`

## 7. Teardown

```bash
cd terraform && terraform destroy
```

Task definition revisions that Jenkins registered are not in Terraform state. They are free, but to remove them:

```bash
for arn in $(aws ecs list-task-definitions --family-prefix weather-app --query 'taskDefinitionArns[]' --output text); do
    aws ecs deregister-task-definition --task-definition "$arn" > /dev/null
done
```
