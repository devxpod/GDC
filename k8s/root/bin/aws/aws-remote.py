#!/usr/bin/env python
import boto3
import os
import click
import sys


class Params(object):
    def __init__(self, profile=None, region=None):
        self.profile = profile
        self.region = region


def even_spaces(string, spaces=12):
    """
    Even spacing for multi-column output
    """
    return string + ' ' * (int(spaces) - len(string))


def find_instance_id(instance_id, aws_profile, aws_region):
    """
    Looks at provided instance_id, and if it does not start with "-i", looks up instance_id based on Name tag
    """
    if str(instance_id).startswith('i-'):
        return instance_id
    else:
        try:
            print(f'Finding instance_id for {instance_id}...')
            boto_session = boto3.Session(profile_name=aws_profile, region_name=aws_region)
            ec2_client = boto_session.client('ec2')
            instance_filter = [{
                'Name': 'tag:Name',
                'Values': [instance_id]
            }]
            ec2_instance = ec2_client.describe_instances(Filters=instance_filter)
            instance_id = ec2_instance['Reservations'][0]['Instances'][0]['InstanceId']
            print(f'Found {instance_id}')
        except Exception as e:
            print(f'Could not find instance_id for {instance_id}')
            print(str(e))
            sys.exit(1)
        return instance_id


@click.group()
@click.option('--profile', default=None, help='Specify AWS profile')
@click.option('--region', default=None, help='Specify AWS region')
@click.pass_context
def cli(ctx, profile, region):
    """
    AWS Remote is a simple, command line tool to view and interact with AWS instances via SSM.
    Requires the AWS CLI and Session Manager Plugin to be installed locally.
    """
    ctx.obj = Params(profile, region)


@cli.command(name='list')
@click.pass_obj
def list_instances(ctx):
    """
    List EC2 instances and SSM management status
    """
    try:
        boto_session = boto3.Session(profile_name=ctx.profile, region_name=ctx.region)
        ec2_client = boto_session.client('ec2')
        ssm_client = boto_session.client('ssm')
        ec2_instances = ec2_client.describe_instances()
        ssm_instances = ssm_client.describe_instance_information()['InstanceInformationList']
        print(even_spaces('ID', spaces=22), even_spaces('AZ'), even_spaces('Type'),
              even_spaces('State', spaces=10), even_spaces('SSM', spaces=8), even_spaces('Name'))
        for instance in ec2_instances['Reservations']:
            instance = instance['Instances'][0]
            instance_id = instance['InstanceId']
            instance_type = instance['InstanceType']
            instance_az = instance['Placement']['AvailabilityZone']
            instance_state = instance['State']['Name']
            instance_name = ''
            if 'Tags' in instance:
                for tag in instance['Tags']:
                    if tag['Key'] == 'Name':
                        instance_name = tag['Value']
            instance_managed = str(any(instance_id in ssm_instance['InstanceId'] for ssm_instance in ssm_instances)).lower()
            print(even_spaces(instance_id, spaces=22), even_spaces(instance_az),
                  even_spaces(instance_type), even_spaces(instance_state, spaces=10),
                  even_spaces(instance_managed, spaces=8), even_spaces(instance_name))
    except Exception as e:
        print(str(e))


@click.argument('instance_id')
@cli.command()
@click.pass_obj
def session(ctx, instance_id):
    """
    Start SSM session with instance id/name
    """
    aws_profile = f' --profile {ctx.profile}' if ctx.profile else ''
    aws_region = f' --region {ctx.region}' if ctx.region else ''
    instance_id = find_instance_id(instance_id, ctx.profile, ctx.region)
    os.system(f"aws{aws_profile}{aws_region} ssm start-session --target {instance_id}")


@click.argument('instance_id')
@click.argument('instance_port')
@click.argument('local_port')
@cli.command()
@click.pass_obj
def port_forward(ctx, instance_id, local_port, instance_port):
    """
    Start SSM port forward to instance id/name
    """
    aws_profile = f' --profile {ctx.profile}' if ctx.profile else ''
    aws_region = f' --region {ctx.region}' if ctx.region else ''
    instance_id = find_instance_id(instance_id, ctx.profile, ctx.region)
    os.system(f'aws{aws_profile}{aws_region} ssm start-session --target {instance_id} '
              f'--document-name AWS-StartPortForwardingSession --parameters "portNumber"=["{instance_port}"],'
              f'"localPortNumber"=["{local_port}"]')


if __name__ == '__main__':
    cli()
