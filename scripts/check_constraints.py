import json
from pathlib import Path
import importlib.util
import glob

path=Path('overlay/root/chipyard/generators/chipyard/src/main/scala/config/rocket_constraint.py')
spec=importlib.util.spec_from_file_location('rc', path)
mod=importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
for name in glob.glob("usecases/*.json"):
    params=json.loads(Path(name).read_text())
    print(name, mod.validate_params(params))