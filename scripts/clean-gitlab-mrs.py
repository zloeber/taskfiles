#!/usr/local/bin/python3
"""
Find and optionally remove aged MR requests on a project in Gitlab
"""
import os
import json
import datetime
import click
import gitlab
from pprint import pprint

gitlab_url = os.getenv("GITLAB_URL", "https://api.gitlab.com")
gitlab_token =  os.getenv("GITLAB_TOKEN")
verbose = os.getenv("VERBOSE", "")

def get_project_id(gl:gitlab.Gitlab, project_path: str = ""):
    print(f"Validating gitlab path: {project_path}")
    if project_path == "":
        project_path = os.getcwd()

    # Search for the project ID based on the project path
    projects = gl.projects.list(search=project_path)
    for project in projects:
        if project.path_with_namespace == project_path:
            return project.id

    # If project ID is not found, raise an error
    raise ValueError('Project ID not found for the current project path')


@click.command()
@click.option('--project-path', prompt='Enter the project path', help='GitLab project path', default="idam-pxm/vault-ops/vault-controller")
@click.option('--project-id', help='GitLab project ID', default="")
@click.option('--days', prompt='Enter the number of days', type=int, help='Number of days', default=14)
@click.option('--remove', is_flag=True, help='Remove the merge requests')
def show_merge_requests(project_path, project_id, days, remove):
    print(f"gitlab_url: {gitlab_url}")
    gl = gitlab.Gitlab(url=gitlab_url, private_token=gitlab_token)
    try:
        gl.auth()
        print(f"Authenticated: <redacted>")
    except Exception as err:
        print(f"err: {err}")

    if project_path != "":
        project = gl.projects.get(project_path)
    elif project_id == "":
        raise ValueError('Project ID not found for the current project path')
    else:
        project = gl.projects.get(project_id)
    
    print(f"project.id: {project.id}")

    # Get all MRs still open
    merge_requests = project.mergerequests.list(state='opened', get_all=True)
    print (f"Total MR Requests: {len(merge_requests)}")

    today = datetime.datetime.now().date()
    older_than = today - datetime.timedelta(days=days)
    output = []
    for mr in merge_requests:
        created_date = datetime.datetime.strptime(mr.created_at, '%Y-%m-%dT%H:%M:%S.%f%z').date()
        days_old = (today - created_date).days
        if created_date < older_than:
            mr_data = {
                "project": project.name,
                "title": mr.title,
                "source_branch": mr.source_branch,
                "target_branch": mr.target_branch,
                "author": mr.author['name'],
                "author_id": mr.author.get('id', ""),
                "days_old": days_old
            }
            if verbose:
                pprint(mr_data)

            output.append(mr_data)
            if remove:
                print(f"Removing MR (This does not touch the source branch: {mr.source_branch})...")
                mr.delete()
    print()
    print(f"Total Aged Entries: {len(output)}")
    print()
    save_file = os.getenv("SAVE_FILE", "")
    if save_file != "":
        print(f"Saving output as {save_file}")
        with open(save_file, 'w') as json_file:
            json.dump(output, json_file)

if __name__ == '__main__':
    show_merge_requests()