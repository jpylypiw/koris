"""Defines test data shared among tests"""

# pylint: disable=invalid-name,missing-docstring

from unittest.mock import MagicMock
from munch import Munch


CONFIG = {
    "n-nodes": 3,
    "n-masters": 3,
    "keypair": "otiram",
    "availibility-zones": ['nbg6-1a', 'nbg6-1b'],
    "cluster-name": "test",
    'private_net': {
        'name': 'test-net',
        'router': {
            'name': 'myrouter1',
            'network': 'ext02'
        },
        'subnet': {
            'name': 'foobar',
            'cidr': '192.168.0.0/24'
        }
    },
    "security_group": "test-group",
    "image": "ubuntu 16.04",
    "node_flavor": "ECS.C1.2-4",
    "master_flavor": "ECS.C1.4-8",
    'storage_class': "TestStorageClass"
}


def default_lb():
    """A default LoadBlaancer Object as returned from the OpenStack SDK"""

    LB = MagicMock()
    LB.provider = "amphora"
    LB.description = "test"
    LB.admin_state_up = True
    LB.pools = [{'id': 'f349fc6b-f1f3-4d6b-8f21-5499abf1c0d5'},
                {'id': 'f8bbd252-4fed-4f59-9c17-0d63b05c5863'},
                {'id': 'fae6fafa-39b7-49e3-92c5-8b76ea122c6b'}]
    LB.created_at = "2019-03-28T13:16:57"
    LB.provisiong_status = "ACTIVE"
    LB.updated_at = "2019-03-28T13:24:07"
    LB.vip_qos_policy_id = None
    LB.vip_network_id = "4062419a-587b-4a87-9012-869c8716b0ec"
    LB.listeners = [{'id': 'ada8c529-55c1-43b6-94ca-8730a118d459'},
                    {'id': '50e334da-4056-48ab-8b93-4dfa70816f49'},
                    {'id': '5a0221b5-9726-421f-bb2c-a8729380d738'}]
    LB.vip_port_id = "019f6882-1f52-4e0c-82f4-6602a6b666fa"
    LB.flavor_id = ""
    LB.vip_address = "192.168.0.6"
    LB.vip_subnet_id = "cabac7ce-b094-45df-a55e-60763d7a1eca"
    LB.project_id = "f2b5a80b06344b2790d008493486ca06"
    LB.id = "6a1aa11d-9f0a-488f-ae74-a35d54a8f3c6"
    LB.operating_status = "ONLINE"
    LB.name = "test-lb"
    LB.location = default_location()


def default_project():
    PR = Munch()
    PR.id = "2b5a80b06344b2790d008493486ca06"
    PR.name = "test-project"
    PR.domain_id = None
    PR.domain_name = None

    return PR


def default_location():
    LOC = Munch()
    LOC.cloud = "envvars"
    LOC.region_name = "de-nbg6-1"
    LOC.zone = None
    LOC.project = default_project()

    return LOC