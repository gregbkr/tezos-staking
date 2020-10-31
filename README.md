# Tezos staking on AWS cloud

> Baking Tezos on server in AWS cloud

**Your takeaways from this post**
- Deploy a baking node to stake Tezos in testnet
- Semi automated infrastructure deployment (terraform, cloud-config, AWS, snapshot)
- A setup to obtain high security for your funds
- Some basic monitoring and steps to fix commum issues

## Prerequites
- AWS account
- Terraform Cli and cloud account (free)

## Deploy Server Infra
- Clone this repo and go to dir: `cd terraform` 
- Init: `terraform init`
- Plan: `terraform plan`
- Deploy: `terraform apply`
- If error `no valid credential sources for Terraform AWS Provider found`: don't forget to change `execution mode -> local` in [settings](https://app.terraform.io/app/gregbkr/workspaces/eth2-prysm-testnet/settings/general)
- Ssh on server: `ssh tezos@<public_IP>`

## Run Tezos baker

### Initial check
Terraform + cloud-init should have run and and server should be ready. Please run the following checks:
- Check that cloud-init has finished (or wait for it): `tail /var/log/cloud-init-output.log -n1000 -f`
- Tezos binaries: `ls -la /usr/local/bin/tezos*`

### Build and run from source (recommended)
Setup node on testnet (carthagenet) 
```
tezos-node identity generate
tezos-node config init --network carthagenet
cat ~/.tezos-node/config.json 
```
Get blocks from snapshot
```
mkdir /sdh/download
wget https://snapshots-tezos.giganode.io/snapshot-testnet_28-10-2020-01:36_834903_BLjRuZU1VsKUXwyNbK9dMkw9hNaSyfV4Q2y8dDZcMLHPZ2qCD7z.full -O /sdh/download/cartha.full
tezos-node snapshot import /sdh/download/cartha.full --block BLjRuZU1VsKUXwyNbK9dMkw9hNaSyfV4Q2y8dDZcMLHPZ2qCD7z
(It takes 1 hour!)
```
Start node: `sudo systemctl status tezos-node`

Check node status
```
journalctl -u tezos-node -ef
tezos-client bootstrapped
tezos-client get timestamp
tezos-client rpc get /chains/main/blocks/head/header/shell
```
Create account 
```
tezos-client gen keys chef
tezos-client list known contracts
tezos-client list known addresses
```
Use https://faucet.tzalpha.net/ to get the tz1.json file
```
tezos-client activate account alice with "tz1.json"
tezos-client transfer <AMOUNT> from alice to chef --burn-cap 0.257
tezos-client get balance for chef
(45668.597577 ꜩ)
```
Baker registration
```
tezos-client show address chef
# tz1MobkJA1cr9oLh8RG5GACRcP1tp8NzXgAu
tezos-client register key chef as delegate
```
Check?
```
tezos-client rpc get /chains/main/blocks/head/helpers/baking_rights\?cycle=300\&delegate=tz1MobkJA1cr9oLh8RG5GACRcP1tp8NzXgAu\&max_priority=2
(this fails...)
```
Run baker, endorser, accuser
```
sudo systemctl status tezos-baker
sudo systemctl status tezos-endorser
sudo systemctl status tezos-accuser
```
Check
```
ps -aux | grep tezos
journalctl -u tezos-[baker|endorser|accuser|node] -ef  # Choose -u unit
```
Check your baker status, rolls, payouts on Tezos [explorer](https://carthagenet.tezblock.io/account/tz1MobkJA1cr9oLh8RG5GACRcP1tp8NzXgAu)

## Delegate more Tezos to your baker
- From your or friend laptop, install a tezos wallet. We will use `Tezos-client` and the same steps as our server `Build and run from source`
- Connect the client to a public node, so you don't have to fully sync the blocks on your laptop: `tezos-client -A rpcalpha.tzbeta.net -S -P 443 bootstrapped`
- Save the config: `tezos-client -A rpcalpha.tzbeta.net -S -P 443 config update` and check it: `cat ~/.tezos-client/config`
- Connect your ledger (if issue check [tezos doc](https://tezos.gitlab.io/user/key-management.html#tezos-wallet-app), [Ledger app doc](https://github.com/obsidiansystems/ledger-app-tezos))
- List and import keys: 
```
tezos-client list connected ledgers
tezos-client import secret key my_ledger ledger://XXXXXXXXXX     # I used the first one
tezos-client list known addresses
tezos-client show ledger ledger://XXXXXXXXX   # display info
```
- Get some Tezos to this `ledger`, from faucet for example.
- Address our remote baker account to our local client: `tezos-client add address chef tz1MobkJA1cr9oLh8RG5GACRcP1tp8NzXgAu`
- Delegate all tezos in `ledger` account to our baker `chef` address: `tezos-client set delegate for ledger_rc to chef`
- (Optional) to un-delegate: `tezos-client withdraw delegate from <implicit_account>`


## Staking info
- Tz inflation: `~ 5%`
- 1 roll: 8000tz = minimum amount to start baking
- Security Deposit:
  - `BLOCK_SECURITY_DEPOSIT = 512 ꜩ` per block created 
  - `ENDORSEMENT_SECURITY_DEPOSIT = 64 ꜩ` per endorsement slot
  - Security deposit need vs total staking: `~ 9%`. (if you stake 100 000tz from clients and yourselft, your baker needs 10 000tz in sec dep)
  - More info:
    -  https://tezos.gitlab.io/master/whitedoc/proof_of_stake.html
    - https://tezos.stackexchange.com/questions/456/security-deposit-calculation

## To do
- [ ] Security: signer or separate baker vs node?
- [ ] Monitor baking
- [ ] Amount to put in deposit
- [x] Activate snapshot 
  - [ ] Test Tezos or AWS Snapshot on new VM
- [ ] Migrate baker Server to final server
  - [ ] Use systemctl instead of noup

## Annexes

### Snapshot 

Sources
- https://snapshots.tulip.tools/#/
- https://snapshots-tezos.giganode.io/

Export a snapshot:
```
tezos-client rpc get /chains/main/blocks/head | more
tezos-node snapshot export --block BLgwgZno23eeCk4vfBZaKAwQCFsxTBFUE2wNnMUReH8bLwNjN47 Download/cartha-BLgwgZno23eeCk4vfBZaKAwQCFsxTBFUE2wNnMUReH8bLwNjN47.export
```