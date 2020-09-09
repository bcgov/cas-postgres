#!/usr/bin/env python

import logging
import os
import socket
import sys
import time

import kubernetes.client as k8s_client
import kubernetes.config as k8s_config
from kubernetes.client.rest import ApiException
from urllib3.exceptions import HTTPError
from six.moves.http_client import HTTPException

logger = logging.getLogger(__name__)


class CoreV1Api(k8s_client.CoreV1Api):

    def retry(func):
        def wrapped(*args, **kwargs):
            count = 0
            while True:
                try:
                    return func(*args, **kwargs)
                except (HTTPException, HTTPError, socket.error, socket.timeout):
                    if count >= 10:
                        raise
                    logger.info('Throttling API requests...')
                    time.sleep(2 ** count * 0.5)
                    count += 1
        return wrapped

    @retry
    def patch_namespaced_endpoints(self, *args, **kwargs):
        return super(CoreV1Api, self).patch_namespaced_endpoints(*args, **kwargs)


def patch_master_endpoint(api, namespace, cluster):
    addresses = [k8s_client.V1EndpointAddress(ip=os.environ['POD_IP'])]
    ports = [k8s_client.V1EndpointPort(name='postgresql', port=5432)]
    subsets = [k8s_client.V1EndpointSubset(addresses=addresses, ports=ports)]
    body = k8s_client.V1Endpoints(subsets=subsets)
    return api.patch_namespaced_endpoints(cluster, namespace, body)

def delete_pod(namespace, pod_name):
  try:
      k8s_client.load_incluster_config()
  except:
      k8s_client.load_kube_config()

  configuration = k8s_client.Configuration()
  api_instance = k8s_client.CoreV1Api(k8s_client.ApiClient(configuration))

  try:
    delete_options = k8s_client.V1DeleteOptions()
    api_response = api_instance.delete_namespaced_pod(
        name=pod_name,
        namespace=namespace,
        body=delete_options)
    print(api_response)
  except ApiException as e:
      print("Exception when calling CoreV1Api->delete_namespaced_pod: %s\n" % e)

def main():
    logging.basicConfig(format='%(asctime)s %(levelname)s: %(message)s', level=logging.INFO)
    if len(sys.argv) != 4 or sys.argv[1] not in ('on_start', 'on_stop', 'on_role_change'):
        sys.exit('Usage: %s <action> <role> <cluster_name>', sys.argv[0])

    action, role, cluster = sys.argv[1:4]

    k8s_config.load_incluster_config()
    k8s_api = CoreV1Api()

    namespace = os.environ['POD_NAMESPACE']
    pod_name = 'cas-postgres-patroni-0'#os.environ['POD_NAME']

    print(role, action)#, os.environ['KILL_POD_ON_DEMOTE'])

    if role == 'master' and action in ('on_start', 'on_role_change'):
        patch_master_endpoint(k8s_api, namespace, cluster)

    if role == 'replica' and action == 'on_role_change': #and os.environ['KILL_POD_ON_DEMOTE']:
        print('deleting replica...')
        print(role, action)#, os.environ['KILL_POD_ON_DEMOTE'])
        delete_pod(namespace, pod_name)


if __name__ == '__main__':
    main()
