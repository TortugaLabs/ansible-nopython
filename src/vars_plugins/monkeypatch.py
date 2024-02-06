#
# Based: https://github.com/gekmihesg/ansible-openwrt/raw/master/vars_plugins/monkeypatch.py
#
import os
from ansible.plugins.action import ActionBase
from ansible.plugins.vars import BaseVarsPlugin
try:
    from ansible.utils.collection_loader import resource_from_fqcr
except ImportError:
    resource_from_fqcr = lambda x: x

GROUP_NAME = 'nopython'
MODULE_PREFIX = 'nopython_'

def _fix_module_args(module_args):
    for k, v in module_args.items():
        if v is None:
            module_args[k] = False
        elif isinstance(v, dict):
            _fix_module_args(v)
        elif isinstance(v, list):
            module_args[k] = [False if i is None else i for i in v]

def _configure_module(self, module_name, module_args, task_vars=None):
    if task_vars is None:
        task_vars = dict()
    if self._task.delegate_to:
        real_vars = task_vars.get('ansible_delegated_vars', dict()).get(self._task.delegate_to, dict())
    else:
        real_vars = task_vars

    if real_vars.get('ansible_connection', '') not in ('local',) and \
            GROUP_NAME in real_vars.get('group_names', list()):
        leaf_module_name = resource_from_fqcr(module_name)
        nopython_module = self._shared_loader_obj.module_loader.find_plugin(MODULE_PREFIX + leaf_module_name, '.sh')
        if nopython_module:
            module_name = os.path.basename(nopython_module)[:-3]
    else:
        nopython_module = None

    (module_style, module_shebang, module_data, module_path) = \
            self.__configure_module(module_name, module_args, task_vars)

    if nopython_module:
        with open(_wrapper_file, 'r') as f:
            wrapper_data = f.read()
        if type(module_data) is bytes:
            module_data = module_data.decode()
        module_data = wrapper_data.replace('\n. "$_script"\n', '\n' + module_data + '\n')
        if len(os.getenv('NOPYTHON_DEBUG','')) > 0:
          with open('module_data','w') as fp:
            fp.write(module_data)
        _fix_module_args(module_args)

    return (module_style, module_shebang, module_data, module_path)

if ActionBase._configure_module != _configure_module:
    _wrapper_file = os.path.join(os.path.dirname(__file__), '..', 'files', 'wrapper.sh')
    ActionBase.__configure_module = ActionBase._configure_module
    ActionBase._configure_module = _configure_module

class VarsModule(BaseVarsPlugin):
    def get_vars(*args, **kwargs):
        return dict()
