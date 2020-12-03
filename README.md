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
tezos-client gen keys chef --encrypted
tezos-client list known contracts
tezos-client list known addresses
```
Backup your keys for chef somewhere very safe:
```
cat ~/.tezos-client/secret_keys
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
Check our current cycle [here](https://carthagenet.tezblock.io/). The command below should return our baking right in this or next cycle 
```
tezos-client rpc get /chains/main/blocks/head/helpers/baking_rights\?cycle=412\&delegate=tz1MobkJA1cr9oLh8RG5GACRcP1tp8NzXgAu\&max_priority=2

[ { "level": 845854, "delegate": "tz1MobkJA1cr9oLh8RG5GACRcP1tp8NzXgAu",
    "priority": 0, "estimated_time": "2020-11-03T21:10:47Z" },
  { "level": 845927, "delegate": "tz1MobkJA1cr9oLh8RG5GACRcP1tp8NzXgAu",
    "priority": 1, "estimated_time": "2020-11-03T21:47:57Z" },
  { "level": 846883, "delegate": "tz1MobkJA1cr9oLh8RG5GACRcP1tp8NzXgAu",
    "priority": 0, "estimated_time": "2020-11-04T05:45:17Z" },
  { "level": 846988, "delegate": "tz1MobkJA1cr9oLh8RG5GACRcP1tp8NzXgAu",
    "priority": 0, "estimated_time": "2020-11-04T06:37:47Z" } ]
```
Run baker, endorser, accuser
```
sudo systemctl status tezos-node.service tezos-baker.service tezos-endorser.service tezos-accuser.service
```
Check
```
ps -aux | grep tezos
journalctl -u tezos-[baker|endorser|accuser|node] -ef  # Choose -u unit
```
Check your baking/endorsing rights and rewards on Tezos [explorer](https://carthagenet.tezblock.io/account/tz1MobkJA1cr9oLh8RG5GACRcP1tp8NzXgAu)

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

## Staking faq
- Tz inflation: `~ 5%`
- 1 roll: 8000tz = minimum amount to start baking
- Stated staking, when I will see the first rewards: 
  - Need to wait the current cycle (25 days in mainnet, half in testnet) to be finished, they you will be included for the next one. Check Tezos [explorer](https://carthagenet.tezblock.io/account/tz1MobkJA1cr9oLh8RG5GACRcP1tp8NzXgAu)
- Security Deposit: how much Tz to you need to keep on your baker, if you plan to stake 100 000Tz in total (you and delegation from user)
  - Info: 
    - `BLOCK_SECURITY_DEPOSIT = 512 ꜩ` per block created 
    - `ENDORSEMENT_SECURITY_DEPOSIT = 64 ꜩ` per endorsement slot
  - => Security deposit need vs total staking: `~ 9%` => so we will need around 10 000Tz on your baker server.
  - Calculation explation:
    - https://tezos.gitlab.io/master/whitedoc/proof_of_stake.html
    - https://tezos.stackexchange.com/questions/456/security-deposit-calculation

## Monitoring

[Kiln](https://gitlab.com/tezos-kiln/kiln/-/blob/develop/docs/config.md) is a great monitoring tools, but heavy.

## Security

- Open only port 9732 to the world, close everything else
- Don't open ssh to world, use bastion or AWS SSM 
- Protect baker secret key (hot wallet):
  - Encrypt secret key on cloud VM (`tesos-client gen key chef --encrypt`)
  - Or better, use remote signer from a controlled raspberry at home + ledger nano attached
  - Or use cloud HSM with project [1](https://github.com/tacoinfra/remote-signer), [2](https://github.com/ecadlabs/signatory), be aware then might be still in beta...

## To do
- [x] Security: signer or separate baker vs node? 
- [x] Use node in --private-mode? don't need, overkill
- [x] Monitor baking -> kiln: not sure as heavy, monitor systemd instead + telegram/email alert
- [x] Amount to put in deposit (can be ledger protected? Yes, with ledger baking app)
- [x] Tezos Snapshot or VM snapshot?
- [x] Migrate baker Server to final server
  - [x] Use systemctl instead of noup
  - [ ] Recover keys
  - [ ] Recover blockchain from snapshot

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

My test nodes:
- [Manual test](https://carthagenet.tezblock.io/account/tz1MobkJA1cr9oLh8RG5GACRcP1tp8NzXgAu?tab=Delegations)
- [Remote signer test](https://carthagenet.tezblock.io/account/tz1a5b4k4varsfcfRNpSSbGeKTXqarUhq3n1)