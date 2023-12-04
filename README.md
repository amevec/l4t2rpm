# l4t2rpm
This is a simple package scraper to do alien conversions en masse for testing in UBI-based images.

Alien prefers these to be run as root to be able to chown things together. 

To build the pytorch Docker image, run: `podman build -f ./docker/RHPyTorch.Dockerfile ./`

You'll want to complete the build on a RH machine with podman, because otherwise your entitlement won't mount in. You can add in a RUN line to activate a subscription on a developer account:
```
RUN subscription-manager register --username=${USER} --password=${PASS} && subscription-manager attach
```

This build will also require the codereadybuilder repo: `Subscription-manager repos --enable codeready-builder-for-rhel-9-$(arch)-rpms`
