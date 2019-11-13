#!/bin/bash
echo "c.JupyterHub.port = 8443" >> /etc/jupyterhub/jupyterhub_config.py

service jupyterhub restart