IMG_NAMESPACE = flag5
IMG_NAME = clustersecret
IMG_FQNAME = $(IMG_NAMESPACE)/$(IMG_NAME)
IMG_VERSION = 0.0.8
CHART_NAME = $(IMG_NAME)wrapper
CHART_VERSION = $(IMG_VERSION)

.PHONY: container push clean arm-container arm-push arm-clean
all: container push
arm: arm-container arm-push
clean: clean arm-clean


container:
	sudo docker build -t $(IMG_FQNAME):$(IMG_VERSION) -t $(IMG_FQNAME):latest .

push: container
	sudo docker push $(IMG_FQNAME):$(IMG_VERSION)
	sudo docker push $(IMG_FQNAME):latest

clean:
	sudo docker rmi $(IMG_FQNAME):$(IMG_VERSION)

arm-container:
	sudo docker build -t $(IMG_FQNAME):$(IMG_VERSION)_arm32 -f Dockerfile.arm .
	
arm-push: arm-container
	sudo docker push $(IMG_FQNAME):$(IMG_VERSION)_arm32

arm-clean:
	sudo docker rmi $(IMG_FQNAME):$(IMG_VERSION)_arm32

beta:
	sudo docker build -t $(IMG_FQNAME):$(IMG_VERSION)-beta .
	sudo docker push $(IMG_FQNAME):$(IMG_VERSION)-beta

chart:
	#
	# FRAGILE!
	# Generate a helm chart out of yaml/0*.yaml files and
	# chartframework/*/*.
	#
	# An improvement would be to deprecate yaml/0*.yaml and
	# to introduce a proper helm chart. Such a helm chart, when
	# templated, could (re)produce the (current) contents of
	# yaml/0*.yaml.
	#
	mkdir -p build/chart/$(CHART_NAME)
	rm -rf build/chart/$(CHART_NAME)
	cp -R chart-framework build/chart/$(CHART_NAME)
	for i in `find build/chart/$(CHART_NAME) -type f`; do \
	  sed -i \
	    -e s@__IMG_FQNAME__@$(IMG_FQNAME)@g \
	    -e s@__IMG_VERSION__@$(IMG_VERSION)@g \
	    -e s@__CHART_NAME__@$(CHART_NAME)@g \
	    -e s@__CHART_VERSION__@$(CHART_VERSION)@g \
	  $${i}; done
	cat yaml/00_rbac.yaml \
	  | sed -e '1,/^---/d' -e 's/^\( *namespace:\).*/\1 {{ .Release.Namespace }}/' \
	  > build/chart/$(CHART_NAME)/templates/00_rbac.yaml
	cat yaml/01_crd.yaml \
	  | sed -e 's/^\( *namespace:\).*/\1 {{ .Release.Namespace }}/' \
	  > build/chart/$(CHART_NAME)/templates/01_crd.yaml
	cat yaml/02_deployment.yaml \
          | sed \
            -e 's/^\( *namespace:\).*/\1 {{ .Release.Namespace }}/' \
            -e 's/^\( *image:\) *\(.*\)/\1 {{ .Values.image.registry }}\2/' \
            -e 's/flag5\/clustersecret/{{ .Values.image.repository }}/' \
            -e 's/0\.0\.8-beta/{{ .Values.image.tag }}/' \
          > build/chart/$(CHART_NAME)/templates/02_deployment.yaml
	helm package build/chart/$(CHART_NAME) --destination build/chart/

chart-clean:
	rm -rf build/chart/$(CHART_NAME)
