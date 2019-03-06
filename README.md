# Introduction

Install Jenkins in Ubuntu 18.04.

# Requires

- Python 3.7+
- pipenv
- make
- git
- curl
- ssh-keygen
- ssh configured for target hosts

# Design

The stack in use is,

- Ubuntu 18.04 host OS
- Docker
- Jenkins
    - Official Docker image
    - Some configuration done before Jenkins is started
    - CLI is run in its own container
- nginx
    - Official Docker image
    - Reverse proxy for Jenkins
    - TLS termination
- Let's Encrypt
    - TLS certificate created
    - Renewal is _not_ automated
- Docker Compose
    - Runs Jenkins and nginx containers
    - Controlled with systemd
- Ansible
    - Configures the host end-to-end
    - Includes playbook to undo almost all changes made during setup
    - Uses my very opinionated open source [Ansible roles](https://github.com/codeghar/ansible-roles)
    - _ansible/hosts_ file has initial configuration that needs to be modified for your needs

# Setup

Read through this section in its entirety before executing these steps.

    $ make init

    $ make generate-password

Enter a new, secure password.

Edit _ansible/play-jenkins.yml_ and change _password: CHANGEME_ to
_password: VALUE_, where VALUE is the output of the above step.

    $ make generate-password

Enter a new, secure password.

Edit _ansible/play-workers.yml_ and change _password: CHANGEME_ to
_password: VALUE_, where VALUE is the output of the above step.

    $ export CERT_ADMIN_EMAIL=CHANGEME
    $ export JENKINS_HOST=CHANGEME
    $ make cert

Create a certificate with Let's Encrypt. But first, view _Makefile_ and edit it
as required. Export these environment variables with appropriate values. Then
run ``make cert``.

Edit _ansible/hosts_ file according to your _~/.ssh/config_ setup.

# Use

    $ make jenkins

Read _ansible/roles/jenkins/README.md_ for more information.

    $ make workers

Read _ansible/roles/worker/README.md_ for more information.

    $ make cli-exec

Since you used Let's Encrypt to generate a certificate, ``make cli-exec``
works. If you're using a self-signed certificate or a certificate whose root
certificate authority is not in your trust store, edit _Makefile_ to use
``cd cli && make cli-alt-exec`` instead of ``cd cli && make cli-exec``. You
will have to adjust other _cli-*_ targets accordingly as well. Read
_cli/README.md_ for more information.

# Undo

To undo changes on hosts made with these Ansible roles,

    $ make undo-jenkins
    $ make undo-workers

These are safety-first roles so not everything may be removed.

Read _ansible/roles/jenkins/README.md_ and _ansible/roles/worker/README.md_ for
more information.
