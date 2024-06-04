from jinja2 import Environment, FileSystemLoader

import sys
import os

# 현재 파일의 디렉토리 경로를 가져옵니다.
current_dir = os.path.dirname(os.path.abspath(__file__))

# 부모의 부모 디렉토리를 경로에 추가합니다.
grandparent_dir = os.path.abspath(os.path.join(current_dir, os.pardir, os.pardir))
sys.path.append(grandparent_dir)

# config 모듈을 임포트합니다.
import config

# Jinja2 환경 설정
file_loader = FileSystemLoader('templates')
env = Environment(loader=file_loader)

# main.conf 템플릿 로드
template = env.get_template('main.conf')

# 템플릿 렌더링
rendered_string = template.render(variants=config.variants, forks_data=config.forks_data, versions=config.versions, mods=config.mods)

# 결과를 파일에 저장
with open('dgamelaunch.conf', 'w') as file:
    file.write(rendered_string)

print("The dgamelaunch.conf file has been created.")
