from jinja2 import Environment, FileSystemLoader
import sys
import os
current_dir = os.path.dirname(os.path.abspath(__file__))
grandparent_dir = os.path.abspath(os.path.join(current_dir, os.pardir, os.pardir))
sys.path.append(grandparent_dir)
import config


file_loader = FileSystemLoader('templates')
env = Environment(loader=file_loader)
template = env.get_template('main.conf')
rendered_string = template.render(variants=config.variants, forks_data=config.forks_data, versions=config.versions, mods=config.mods)

with open('dgamelaunch.conf', 'w') as file:
    file.write(rendered_string)

print("The dgamelaunch.conf file has been created.")
