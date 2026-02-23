.PHONY: docker-start docker-stop docker-reset docker-cmd docker-kill docker-build docker-status clean

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

docker-status:
	@cid=$$(docker ps -q --filter "name=^/$(DOCKER_CONTAINER)$$" | head -n 1); \
	if [ -z "$$cid" ]; then cid=$$(docker ps -q --filter ancestor=$(DOCKER_IMAGE) | head -n 1); fi; \
	if [ -z "$$cid" ]; then echo "No running $(DOCKER_IMAGE) container found"; exit 1; fi; \
	echo "--- Container Resources ---"; \
	docker stats --no-stream $$cid; \
	echo "--- Disk Space ---"; \
	docker exec $$cid df -h /
