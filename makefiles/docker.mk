.PHONY: docker-start docker-stop docker-reset docker-cmd docker-kill docker-build docker-status docker-root clean

DOCKER_ROOT_SRC ?= /root
DOCKER_ROOT_DST ?= docker-root
DOCKER_OVERLAYS ?= overlay
DOCKER_DEPS = $(shell find $(DOCKER_OVERLAYS) -type f 2>/dev/null)

define run_on_docker
cid=$$(docker ps -q --filter "name=^/$(DOCKER_CONTAINER)$$" | head -n 1); \
if [ -z "$$cid" ]; then cid=$$(docker ps -q --filter ancestor=$(DOCKER_IMAGE) | head -n 1); fi; \
if [ -z "$$cid" ]; then echo "No running $(DOCKER_IMAGE) container found"; exit 1; fi; \
docker exec $$cid /bin/bash -lc "source /root/chipyard/env.sh && $(1)"
endef

define run_on_docker_raw
cid=$$(docker ps -q --filter "name=^/$(DOCKER_CONTAINER)$$" | head -n 1); \
if [ -z "$$cid" ]; then cid=$$(docker ps -q --filter ancestor=$(DOCKER_IMAGE) | head -n 1); fi; \
if [ -z "$$cid" ]; then echo "No running $(DOCKER_IMAGE) container found"; exit 1; fi; \
docker exec $$cid /bin/bash -lc "$(1)"
endef

define docker_cp_to
cid=$$(docker ps -q --filter "name=^/$(DOCKER_CONTAINER)$$" | head -n 1); \
if [ -z "$$cid" ]; then cid=$$(docker ps -q --filter ancestor=$(DOCKER_IMAGE) | head -n 1); fi; \
if [ -z "$$cid" ]; then echo "No running $(DOCKER_IMAGE) container found"; exit 1; fi; \
docker cp $(1) $$cid:$(2)
endef

define docker_cp_from
cid=$$(docker ps -q --filter "name=^/$(DOCKER_CONTAINER)$$" | head -n 1); \
if [ -z "$$cid" ]; then cid=$$(docker ps -q --filter ancestor=$(DOCKER_IMAGE) | head -n 1); fi; \
if [ -z "$$cid" ]; then echo "No running $(DOCKER_IMAGE) container found"; exit 1; fi; \
docker cp $$cid:$(1) $(2)
endef




docker-build: build$(OUT_SUFFIX).log

build$(OUT_SUFFIX).log : $(DOCKERFILE) $(DOCKER_DEPS)
	docker build --progress=plain -f $(DOCKERFILE) -t $(DOCKER_IMAGE) . > build$(OUT_SUFFIX).log 2>&1

docker-start:
	@docker info >/dev/null 2>&1 || { echo "Docker daemon not running"; exit 1; }
	@cid=$$(docker ps -q --filter "name=^/$(DOCKER_CONTAINER)$$" | head -n 1); \
	if [ -z "$$cid" ]; then cid=$$(docker ps -q --filter ancestor=$(DOCKER_IMAGE) | head -n 1); fi; \
	if [ -n "$$cid" ]; then echo "Docker already running: $$cid"; \
	else \
	  cid=$$(docker ps -aq --filter "name=^/$(DOCKER_CONTAINER)$$" | head -n 1); \
	  if [ -n "$$cid" ]; then docker start $$cid >/dev/null; \
	  else cid=$$(docker run -d --name $(DOCKER_CONTAINER) --entrypoint /bin/bash $(DOCKER_IMAGE) -lc "sleep infinity"); fi; \
	fi; \
	for d in $(DOCKER_OVERLAYS); do \
	  [ -d "$$d" ] || continue; \
	  docker cp "$$d/." $$cid:/; \
	done

docker-stop:
	@cid=$$(docker ps -q --filter "name=^/$(DOCKER_CONTAINER)$$" | head -n 1); \
	if [ -z "$$cid" ]; then cid=$$(docker ps -q --filter ancestor=$(DOCKER_IMAGE) | head -n 1); fi; \
	if [ -z "$$cid" ]; then echo "No running $(DOCKER_IMAGE) container found"; exit 1; fi; \
	docker stop $$cid >/dev/null

docker-reset:
	@cid=$$(docker ps -aq --filter "name=^/$(DOCKER_CONTAINER)$$" | head -n 1); \
	if [ -n "$$cid" ]; then docker rm -f $$cid >/dev/null; fi; \
	$(MAKE) docker-start

docker-cmd:
	@set -e; \
	[ -n "$(CMD)" ] || { echo "Set CMD=..."; exit 1; }; \
	if [ -n "$(RAW)" ]; then \
	  $(call run_on_docker_raw,$(CMD)); \
	else \
	  $(call run_on_docker,$(CMD)); \
	fi

docker-kill:
	@docker ps -q | xargs -r docker rm -f

docker-mount:
	@mount_dir="mount/$(DOCKER_CONTAINER)"; \
	mkdir -p "$$mount_dir"; \
	cid=$$(docker ps -q --filter "name=^/$(DOCKER_CONTAINER)$$" | head -n 1); \
	if [ -z "$$cid" ]; then \
	    echo "No running container found: $(DOCKER_CONTAINER)"; exit 1; \
	fi; \
	# Get the container's mount point in overlay2 \
	container_dir=$$(docker inspect --format '{{.GraphDriver.Data.MergedDir}}' $$cid); \
	if [ -z "$$container_dir" ]; then \
	    echo "Failed to find overlay2 directory for $$cid"; exit 1; \
	fi; \
	echo "Creating symlink $$mount_dir -> $$container_dir"; \
	ln -sfn "$$container_dir" "$$mount_dir"; \
	echo "Done. You now have direct access to /root of $(DOCKER_CONTAINER) via $$mount_dir"
docker-bash:
	@cid=$$(docker ps -q --filter "name=^/$(DOCKER_CONTAINER)$$" | head -n 1); \
	if [ -z "$$cid" ]; then \
	    cid=$$(docker ps -q --filter ancestor=$(DOCKER_IMAGE) | head -n 1); \
	fi; \
	if [ -z "$$cid" ]; then \
	    echo "No running container found for $(DOCKER_CONTAINER) or $(DOCKER_IMAGE)"; exit 1; \
	fi; \
	echo "Attaching to container $$cid..."; \
	docker exec -it $$cid /bin/bash -l
docker-status:
	@docker info >/dev/null 2>&1 || { echo "Docker daemon: NOT RUNNING"; exit 1; }

	@printf "\n==============================\n"
	@printf "      DOCKER STATUS REPORT\n"
	@printf "==============================\n\n"

	@# --- Docker Root & Host Disk ---
	@root_dir=$$(docker info -f '{{.DockerRootDir}}'); \
	printf "Docker Root Dir : %s\n" "$$root_dir"; \
	printf "Host FS Usage   :\n"; \
	df -h "$$root_dir" | awk 'NR==1 || NR==2'; \
	printf "\n"

	@# --- Docker Disk Usage ---
	@printf "Docker Disk Usage:\n"; \
	docker system df; \
	printf "\n"

	@# --- All Containers (Running + Stopped) ---
	@printf "All Containers:\n"; \
	docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"; \
	printf "\n"

	@# --- Resource Usage ---
	@printf "Live Resource Usage:\n"; \
	docker stats --no-stream \
		--format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"; \
	printf "\n"

	@# --- Container Sizes & Commands (Human Readable) ---
	@printf "Container Sizes & Commands:\n"; \
	docker ps -a --format "{{.Names}}" | while read c; do \
		rw=$$(docker inspect --size $$c --format '{{.SizeRw}}'); \
		root=$$(docker inspect --size $$c --format '{{.SizeRootFs}}'); \
		rw_h=$$(numfmt --to=iec --suffix=B $$rw 2>/dev/null || echo $$rw); \
		root_h=$$(numfmt --to=iec --suffix=B $$root 2>/dev/null || echo $$root); \
		# Safely get Entrypoint and Cmd even if null \
		entrypoint=$$(docker inspect --format '{{if .Config.Entrypoint}}{{join .Config.Entrypoint " "}}{{end}}' $$c 2>/dev/null); \
		cmd=$$(docker inspect --format '{{if .Config.Cmd}}{{join .Config.Cmd " "}}{{end}}' $$c 2>/dev/null); \
		printf "  %-25s RW: %-8s  Total: %-8s  Entrypoint: %-25s  Cmd: %s\n" $$c $$rw_h $$root_h "$$entrypoint" "$$cmd"; \
	done


	@printf "\n==============================\n\n"

docker-root:
	@cid=$$(docker ps -q --filter "name=^/$(DOCKER_CONTAINER)$$" | head -n 1); \
	if [ -z "$$cid" ]; then cid=$$(docker ps -q --filter ancestor=$(DOCKER_IMAGE) | head -n 1); fi; \
	if [ -z "$$cid" ]; then echo "No running $(DOCKER_IMAGE) container found"; exit 1; fi; \
	mkdir -p "$(DOCKER_ROOT_DST)"; \
	echo "Copying $$cid:$(DOCKER_ROOT_SRC) -> $(DOCKER_ROOT_DST)"; \
	docker cp "$$cid:$(DOCKER_ROOT_SRC)/." "$(DOCKER_ROOT_DST)"
