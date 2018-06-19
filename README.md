# EventStore on Azure with Terraform

This [Terraform](https://www.terraform.io) plan spins up a multi-node [EventStore](https://eventstore.org) cluster on Ubuntu Linux VMs in Microsoft Azure.

## Details 

The Terraform plan creates:

- An Azure Resource Group
- A virtual network, subnet and security group with rules for EventStore ports and SSH
- A Storage Account, Blob container and the VM disks
- An Availablity Set
- 3 Ubuntu 16.04 LTS virtual machines, plus associated network bits, in the Availability Set
- An Azure Load Balancer configured to handle the external ports for TCP (1112) and HTTP (2114)

After creation of the VMs, it runs `install.sh`, then `configure.sh`, after which you should be able to access the Web UI via
`http://your-resource-name-lb.your-location.cloudapp.azure.com:2114`, logging in with the default `admin`/`changeit` credentials,
which you should then obviously immediately change.

### Variables

- **resource_name_prefix** - will be applied to all resource names and identifiers
- **subscription_id**, **client_id**, **client_secret**, **tenant_id** - your Azure credentials ([how to obtain them](https://www.terraform.io/docs/providers/azurerm/index.html#creating-credentials))
- **location** - The Azure region to run in, e.g. `northeurope`
- **vmusername**, **vmuserpassword** - The Linux login credentials
- **nodes** - The number of EventStore nodes to create. Must be an odd number, probably 3 or 5.
- **vm_size** - The Azure VM size. I suggest [Ds*X*_V2](https://docs.microsoft.com/en-us/azure/virtual-machines/virtual-machines-linux-sizes#dsv2-series) as a minimum.
- **storage_account_type** - Type of Azure Storage account to create for VM disks. You should use [Premium Storage](https://docs.microsoft.com/en-us/azure/storage/storage-premium-storage) for busy production systems.

### Files

- The `ssh` folder must contain the `id_rsa` (private key) and `id_rsa.pub` (public key) that will be used to secure the Linux VMs. **DO NOT** check these into source control.
- The `scripts` folder contains: 
  - The `install.sh` script which is a slightly modified version of the one from packagecloud to set up the EventStore `apt` repos and install `eventstore-oss`.
  - The `configure.sh` script which writes the `eventstore.conf` file with the cluster gossip seeds and starts EventStore. If you want to make further changes to the configuration, just edit the "here document" in this script.
- `main.tf` is the Terraform plan, obviously
- `terraform.tfvars` is where you should put the credentials variables. **DO NOT** check this into source control.

**Because this is a template/example repo, I have not added `terraform.tfvars` or `ssh` to the `.gitignore`. Remember to add them before commiting your own code.**

## Notes

I've deliberately kept this as simple as possible, with no proxies or SSL or anything, so that people can use it as a base.
If I've missed something important or could do something better, PRs or advice in Issues would be great.

If you fork this repo and add bells and whistles, and you want to share your changes, please raise an issue with the URL of your
fork and I'll add it to a list in this README (or I guess you could create a PR with just the README changes).
