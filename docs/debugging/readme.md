# Debugging

## Python
### Pycharm
In **PyCharm** IDE go to `Run->Edit Configurations`  
Click the + in top left and select `Python Debug Server`  
Give it a name of `gdc-python-debug`  
`IDE host name` = `host.docker.internal`  
`Port = 12345`  
Put check in `Redirect output to console`  
Uncheck `Suspend after connect`  
Click the folder icon to the right of `Path mappings` and click the + to add a new one  
`Local Path` = <use  the repo path on the host>  
`Remote` = `/workspace`  
Click `ok` until your back to main IDE window

In the container with project `venv` activated run:
```bash 
pip install pydevd-pycharm~=222.3739.56
```

In the IDE create a file to test the debugger any place in project named `testdebug.py` with content of:
```python
import pydevd_pycharm

pydevd_pycharm.settrace(
"host.docker.internal", port=12345, stdoutToServer=True, stderrToServer=True
)
abc = "123"
print(abc)
```

Put a breakpoint on the line `print(abc)`  
Click the little debug icon in the top of the ide next to the run config you created "gdc-python-debug" (this will start the debug server in the IDE)

Now inside the GDC run: 
```bash
python testdebug.py
```
It should connect to the IDE debug server and the IDE should pause execution on the breakpoint and allow you to do usual debug stuff
