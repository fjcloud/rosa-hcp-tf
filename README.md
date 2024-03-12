# ROSA HCP cluster provison

This example shows how to create a ROSA HCP cluster, operator IAM roles and OIDC provider.
_ROSA_ stands for Red Hat Openshift Service on AWS
and is a cluster that is created in the AWS cloud infrastructure.

To run it:

Provide OCM Authentication Token that you can get from [here](https://console.redhat.com/openshift/token)

```bash
export TF_VAR_token=...
export TF_VAR_oidc_config_id=$(rosa create oidc-config -m auto -y -o json | jq -r .id)
```

then run 

```bash
rosa create operator-roles -m auto --hosted-cp --prefix tf-rosa --oidc-config-id $TF_VAR_oidc_config_id --role-arn arn:aws:iam::034313440371:role/florian-HCP-ROSA-Installer-Role
rosa create oidc-provider -m auto -y --oidc-config-id $OIDC_CONFIG_ID
terraform init
terraform apply --auto-approved
```
