JENKINS_URL ?= NOT_SET
DOCKER_DATA_ROOT ?= /var/lib/docker
DIGITAL_OCEAN_TOKEN ?= NOT_SET
JENKINS_HOST ?= NOT_SET
CERT_ADMIN_EMAIL ?= NOT_SET
FULLCHAINPEM := workspace/conf/live/$(JENKINS_HOST)/fullchain.pem
CERTIFICATEPEM := ansible/roles/jenkins/files/certificate.pem
KEYPEM := ansible/roles/jenkins/files/key.pem

.PHONY: help
help:
	@echo 'Need to run once'
	@echo '    make init'
	@echo '    make generate-password  # Once each for Jenkins and worker'
	@echo '    make cert'
	@echo 'Setup Jenkins'
	@echo '    make jenkins'
	@echo '    make workers'
	@echo 'Undo/reverse Jenkins setup'
	@echo '    make undo-jenkins'
	@echo '    make undo-workers'
	@echo 'Jenkins CLI in a container'
	@echo '    make cli-exec'
	@echo '    make cli-stop'
	@echo '    make cli-start'
	@echo '    make cli-up'
	@echo '    make cli-down'

# -----------------------------------------------------------------------------

.PHONY: init
init:
	pipenv install

.PHONY: jenkins
jenkins: | ansible/roles/docker ansible/roles/jenkins $(CERTIFICATEPEM) $(KEYPEM)
	cd ansible && pipenv run ansible-playbook --extra-vars docker_data_root=$(DOCKER_DATA_ROOT) playbook-jenkins.yml

.PHONY: workers
workers: | ansible/roles/docker ansible/roles/worker ansible/roles/worker/files/key.pub
	cd ansible && pipenv run ansible-playbook playbook-workers.yml

.PHONY: undo-jenkins
undo: | ansible/roles/docker ansible/roles/jenkins
	cd ansible && pipenv run ansible-playbook playbook-undo-jenkins.yml

.PHONY: undo-workers
undo-workers: | ansible/roles/docker ansible/roles/worker
	cd ansible && pipenv run ansible-playbook playbook-undo-workers.yml

.PHONY: cli-exec
cli-exec: cli-up
	cd cli && make cli-exec

# -----------------------------------------------------------------------------

# http://jasonkarns.com/blog/subdirectory-checkouts-with-git-sparse-checkout/
ansible/roles/docker: | ansible/roles
	cd ansible/roles && git init
	cd ansible/roles && git remote add origin https://github.com/codeghar/ansible-roles
	cd ansible/roles && git config core.sparsecheckout true
	echo docker/ | tee -a ansible/roles/.git/info/sparse-checkout
	cd ansible/roles && git pull origin master
	cd ansible/roles && rm -rf .git

# http://jasonkarns.com/blog/subdirectory-checkouts-with-git-sparse-checkout/
ansible/roles/jenkins: | ansible/roles
	cd ansible/roles && git init
	cd ansible/roles && git remote add origin https://github.com/codeghar/ansible-roles
	cd ansible/roles && git config core.sparsecheckout true
	echo jenkins/ | tee -a ansible/roles/.git/info/sparse-checkout
	cd ansible/roles && git pull origin master
	cd ansible/roles && rm -rf .git

ansible/roles/worker: | ansible/roles
	cd ansible/roles && git init
	cd ansible/roles && git remote add origin https://github.com/codeghar/ansible-roles
	cd ansible/roles && git config core.sparsecheckout true
	echo jenkins-worker/ | tee -a ansible/roles/.git/info/sparse-checkout
	cd ansible/roles && git pull origin master
	cd ansible/roles && rm -rf .git

$(CERTIFICATEPEM): | ansible/roles/jenkins $(FULLCHAINPEM)
	cp workspace/conf/live/$(JENKINS_HOST)/fullchain.pem $(CERTIFICATEPEM)

$(KEYPEM): | ansible/roles/jenkins $(FULLCHAINPEM)
	cp workspace/conf/live/$(JENKINS_HOST)/privkey.pem $(KEYPEM)

ansible/roles/worker/files/key.pub: | ansible/roles/worker
	ssh-keygen -t rsa -b 4096 -f ansible/roles/worker/files/key

.PHONY: cli-up
cli-up: cli/jenkins-cli.jar
	cd cli && pipenv install
	cd cli && make cli-up

# -----------------------------------------------------------------------------

ansible/roles:
	mkdir -p ansible/roles

# https://certbot-dns-digitalocean.readthedocs.io/en/stable/
# https://certbot.eff.org/docs/using.html#dns-plugins
.PHONY: cert
cert: $(FULLCHAINPEM)
$(FULLCHAINPEM): | workspace/conf workspace/logs workspace/work workspace/digitalocean.ini
	pipenv run certbot certonly \
		--agree-tos \
		-m '$(CERT_ADMIN_EMAIL)' \
		--config-dir workspace/conf \
		--logs-dir workspace/logs \
		--work-dir workspace/work \
		--dns-digitalocean \
		--dns-digitalocean-credentials digitalocean.ini \
		--dns-digitalocean-propagation-seconds 60 \
		-d $(JENKINS_HOST)

cli/jenkins-cli.jar: | cli
	curl -o cli/jenkins-cli.jar $(JENKINS_URL)/jnlpJars/jenkins-cli.jar

# -----------------------------------------------------------------------------

workspace/conf: | workspace
	mkdir -p workspace/conf

workspace/logs: | workspace
	mkdir -p workspace/logs

workspace/work: | workspace
	mkdir -p workspace/work

workspace/digitalocean.ini: | workspace
	printf "dns_digitalocean_token = %s\n" "$(DIGITAL_OCEAN_TOKEN)" | tee workspace/digitalocean.ini

cli:
	git clone https://github.com/aikchar/jenkins-cli cli

# -----------------------------------------------------------------------------

workspace:
	mkdir -p workspace

# -----------------------------------------------------------------------------

.PHONY: generate-password
generate-password:
	pipenv run python -c 'from passlib.hash import sha512_crypt; import getpass; print(sha512_crypt.using(rounds=5000))'

.PHONY: cli-stop
cli-stop:
	cd cli && make cli-stop

.PHONY: cli-start
cli-start:
	cd cli && make cli-start

.PHONY: cli-down
cli-down:
	cd cli && make cli-down
