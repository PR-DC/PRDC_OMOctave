# PR-DC OMOctave
GNU Octave scripting OpenModelica interface using ZEROMQ based on OMMatlab available at:<br>
https://github.com/OpenModelica/OMMatlab/

## Requirements
[OpenModelica](https://www.openmodelica.org/)<br>
[GNU Octave](https://www.gnu.org/software/octave/)<br>

Provided interface is partially tested with **GNU Octave 6.2.0** and **OpenModelica 1.16.5**.

## Installation
Clone the repository and add the installation directory to Octave PATH. For Example <br>
```
>> addpath('C:\OMOctave\')
```
You can also directly use the OMOctave package directly from the directory where you have cloned, without need to perform the above steps. But the package cannot be used globally.

## Usage
```
>> omc = OMOctave();
>> omc.sendExpression("getVersion()")
ans =
{
  [1,1] = OpenModelica v1.16.5 (64-bit)
}
>> omc.sendExpression("model a end a;")
ans =
{
  [1,1] = a
}
>> omc.sendExpression('loadFile("C:/Program Files/OpenModelica1.16.5-64bit/OMSens/resource/BouncingBall.mo")')
ans =
{
  [1,1] = true
}
>> omc.sendExpression("getClassNames()")
ans =
{
  [1,1] = BouncingBall
  [1,2] = a
}
>> omc.sendExpression("simulate(BouncingBall)")
ans =

  scalar structure containing the fields:

    resultFile = C:/Users/User/Desktop/OMOctave/BouncingBall_res.mat
    simulationOptions = startTime = 0.0, stopTime = 1.0, numberOfIntervals = 500, tolerance = 1e-006, method = 'dassl', fileNamePrefix = 'BouncingBall', options = '', outputFormat = 'mat', variabl
eFilter = '.*', cflags = '', simflags = ''
    messages = LOG_SUCCESS       | info    | The initialization finished successfully without homotopy method.
LOG_SUCCESS       | info    | The simulation finished successfully.

    timeFrontend = 0.0065355
    timeBackend = 0.0096361
    timeSimCode = 0.0013927
    timeTemplates = 0.0318059
    timeCompile = 8.706928700000001
    timeSimulation = 0.3084547
    timeTotal = 9.0651016
>> omc.close();
```
To see the list of available OpenModelicaScripting API see https://www.openmodelica.org/doc/OpenModelicaUsersGuide/latest/scripting_api.html

## License
Copyright (C) 2021 PR-DC <info@pr-dc.com>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as 
published by the Free Software Foundation, either version 3 of the 
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
