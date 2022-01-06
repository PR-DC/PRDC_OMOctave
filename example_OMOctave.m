% PR-DC OpenModelica Octave Interface test script
% Author: Milos Petrasinovic <mpetrasinovic@prdc.rs>
% PR-DC, Republic of Serbia
% info@pr-dc.com
%
% --------------------
%
% Copyright (C) 2021 PR-DC <info@pr-dc.com>
% 
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU Lesser General Public License as 
% published by the Free Software Foundation, either version 3 of the 
% License, or (at your option) any later version.
%  
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU Lesser General Public License for more details.
%  
% You should have received a copy of the GNU Lesser General Public License
% along with this program.  If not, see <https://www.gnu.org/licenses/>.
%
% --------------------

clear all, clc, close all, tic

%omcpath = "C:/Program Files/OpenModelica1.16.5-64bit/bin/omc.exe";
%omc = OMOctave(omcpath);

omc = OMOctave();
omc.sendExpression("getVersion()")
omc.sendExpression("model a end a;")
omc.sendExpression(['loadFile("C:/Program Files/' ...
  'OpenModelica1.16.5-64bit/OMSens/resource/BouncingBall.mo")'])
omc.sendExpression("getClassNames()")
omc.sendExpression("simulate(BouncingBall)")
omc.close();

disp(' Script has been executed successfully... ');
disp([' Execution time: ' num2str(toc, '%.2f') ' seconds.']);
disp(' -------------------- ');