# Chipyard VLSI Workspace


This repo builds a single Docker image and runs Rocket or BOOM flows inside it.


## Docker

Build image
```bash
make docker-build
```

Start container
```bash
make docker-start
```

Run a command inside the container
```bash
make docker-cmd CMD="ls"
make docker-cmd CMD="ls /" RAW=1
```

## Config Overlays

Local files under `rocket-configs/overlay` and `boom-configs/overlay` are copied into the container root on `make docker-start`.

Put files under the full container path, for example:
```
rocket-configs/overlay/root/chipyard/generators/chipyard/src/main/scala/config/CustomRocketConfigs.scala
rocket-configs/overlay/root/chipyard/vlsi/sky130-rocket.yml
boom-configs/overlay/root/chipyard/vlsi/sky130-boom.yml
```


## Targets

Rocket (default)
```bash
make syn
make par
make power
make syn_power
```

Boom
```bash
make TARGET=boom syn
make TARGET=boom par
make TARGET=boom power
make TARGET=boom syn_power
```



## RTL

Generate verilog once and reuse
```bash
make verilog
make custom_vlog
```

Use CUSTOM_VLOG in vlsi flow
```bash
CUSTOM_VLOG="$(cat custom_vlog.rocket.txt)" make syn
CUSTOM_VLOG="$(cat custom_vlog.boom.txt)" make TARGET=boom syn
```

## Outputs

Rocket outputs (default)
```text
build.rocket.log
verilog.rocket.log
custom_vlog.rocket.txt
syn.rocket.log
par.rocket.log
power.rocket.log
power.rocket.rpt
```

Boom outputs (TARGET=boom)
```text
build.boom.log
verilog.boom.log
custom_vlog.boom.txt
syn.boom.log
par.boom.log
power.boom.log
power.boom.rpt
```

## Scripts

Parameter exploration (random search):
```bash
scripts/param_explore.py --space rocket-configs/overlay/root/chipyard/generators/chipyard/src/main/scala/config/param_rocket.json
```



## Clean

```bash
make clean
make TARGET=boom clean
```
