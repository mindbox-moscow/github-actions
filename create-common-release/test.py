import json
from sys import argv
from os import system
if __name__ == '__main__':
    data_dict=json.loads(argv[1])
    for dic in data_dict:
        system("echo " + dic['project'] + " " + dic['env'])
        system("octo --version")