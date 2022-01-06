% PR-DC OpenModelica Octave Interface
% Author: Milos Petrasinovic <mpetrasinovic@prdc.rs>
% PR-DC, Republic of Serbia
% info@pr-dc.com
%
% --------------------
%
% OMOctave - the OpenModelica Octave API is a free, open source, 
% highly portable Octave-based interactive session handler for Modelica 
% scripting. It provides the modeler with components for creating a complete 
% Modelica modeling, compilation and simulation environment based on the latest 
% OpenModelica library standard available. OMOctave is architectured to combine 
% both the solving strategy and model building. So domain experts (people 
% writing the models) and computational engineers (people writing the solver 
% code) can work on one unified tool that is industrially viable for 
% optimization of Modelica models, while offering a flexible platform for 
% algorithm development and research. OMOctave is not a standalone package, 
% it depends upon the OpenModelica installation.
% OMOctave is implemented in Octave and depends on ZeroMQ - high performance 
% asynchronous messaging library via Octave Forge zeromq package and it 
% supports the Modelica Standard Library version 3.2 that is included in 
% starting with OpenModelica 1.9.2.
%
% To install OMOctave follow the instructions at 
% https://github.com/PR-DC/OMOctave
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
%
% This file is based on OMMatlab.m that is part of OpenModelica.
% Copyright (c) 1998-CurrentYear, Open Source Modelica Consortium (OSMC),
% c/o Linkopings universitet, Department of Computer and Information Science,
% SE-58183 Linkoping, Sweden.
%
% All rights reserved.
%
% THIS PROGRAM IS PROVIDED UNDER THE TERMS OF THE BSD NEW LICENSE OR THE
% GPL VERSION 3 LICENSE OR THE OSMC PUBLIC LICENSE (OSMC-PL) VERSION 1.2.
% ANY USE, REPRODUCTION OR DISTRIBUTION OF THIS PROGRAM CONSTITUTES
% RECIPIENT'S ACCEPTANCE OF THE OSMC PUBLIC LICENSE OR THE GPL VERSION 3,
% ACCORDING TO RECIPIENTS CHOICE.
%
% The OpenModelica software and the OSMC (Open Source Modelica Consortium)
% Public License (OSMC-PL) are obtained from OSMC, either from the above
% address, from the URLs: http://www.openmodelica.org or
% http://www.ida.liu.se/projects/OpenModelica, and in the OpenModelica
% distribution. GNU version 3 is obtained from:
% http://www.gnu.org/copyleft/gpl.html. The
% New BSD License is obtained from:
% http://www.opensource.org/licenses/BSD-3-Clause.
%
% This program is distributed WITHOUT ANY WARRANTY; without even the implied
% warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE, EXCEPT AS
% EXPRESSLY SET FORTH IN THE BY RECIPIENT SELECTED SUBSIDIARY LICENSE
% CONDITIONS OF OSMC-PL.

classdef OMOctave < handle
  properties (Access = public)
    pid = 0
    active
    requester
    portfile
    filename
    modelname
    xmlfile
    resultfile = ''
    csvfile = ''
    mattempdir = ''
    simulationoptions = struct
    quantitieslist = []
    parameterlist = struct
    continuouslist = struct
    inputlist = struct
    outputlist = struct
    mappednames = struct
    overridevariables = struct
    simoptoverride = struct
    inputflag = false
    linearOptions = struct('startTime', '0.0', 'stopTime', '1.0', ...
      'numberOfIntervals', '500', 'stepSize', '0.002', 'tolerance', '1e-6')
    linearfile
    linearFlag = false
    linearmodelname
    linearinputs
    linearoutputs
    linearstates
    linearquantitylist
  end
  methods
    function obj = OMOctave(omcpath)
      obj.pkgForgeCheck('zeromq', '1.5.2')
      
      % Prevent buffer output
      more off
      
      [~, randomstring] = fileparts(tempname);
      if(ispc)
        if nargin ~= 1
          omhome = getenv('OPENMODELICAHOME');
          omhomepath = strrep(fullfile(omhome, 'bin', 'omc.exe'), ...
            '\', '/');
        else
          omhomepath = omcpath;
          [omhome, ~] = fileparts(fileparts(omcpath));
        end
        
        % Add omhome to path environment variabel
        path1 = getenv('PATH');
        setenv('PATH', [path1 omhome]);
        
        cmd = ['START /b "" "' omhomepath ...
          '" --interactive=zmq +z=octave.' randomstring];
        portfile = strcat('openmodelica.port.octave.', randomstring);
      else
        if(ismac && system("which omc") ~= 0)
          if nargin ~= 1
            omhome = '/opt/openmodelica/bin/omc';
          else
            omhome = omcpath;
          end
          cmd = [omhome ' --interactive=zmq -z=octave.' randomstring ' &'];
        else
          if(v)
            omhome = 'omc';
          else
            omhome = omcpath;
          end
          cmd = [omhome ' --interactive=zmq -z=octave.' randomstring ' &'];
        end
        portfile = strcat('openmodelica.', getenv('USER'), ...
          '.port.octave.', randomstring);
      end
      
      if(ispc)
        [~, msg1] = system("tasklist");
        pids1 = cell2mat(cell2mat(regexp(regexp(msg1, ...
          'omc.exe[ ]+[0-9]+ Console', 'match'), '[0-9]+', 'match')));
      end
      
      system([cmd " >nul 2>nul"]);
      
      if(ispc)
        [~, msg2] = system("tasklist");
        pids2 = cell2mat(cell2mat(regexp(regexp(msg2, ...
          'omc.exe[ ]+[0-9]+ Console', 'match'), '[0-9]+', 'match')));
        I = ismember(pids2, pids1);
        obj.pid = pids2(find(~I));
      end
      
      obj.portfile = strrep(fullfile(tempdir, portfile), '\', '/');
      
      while true
        pause(0.01);
        if(isfile(obj.portfile))
          filedata = fileread(obj.portfile);
          break;
        end
      end
      
      try
        obj.active = true;
        obj.requester = zmq_socket(ZMQ_REQ);
        zmq_connect(obj.requester, filedata);
      catch
        obj.active = false;
      end
    end
    
    function reply = sendExpression(obj, expr, len)
      if(obj.active)
        if(nargin == 2)
          len = 2^32;
        end
        zmq_send(obj.requester, expr, 0);
        data = char(zmq_recv(obj.requester, len, 0));

        % Parse replay and return in appropriate Octave
        % structure if possible, otherwise return as normal strings
        reply = obj.parseExpression(data);
      else
        error(["No connection with OMC. Create a new "...
          "instance of OMOctave session"]);
        reply = false;
      end
    end
    
    function ModelicaSystem(obj, filename, modelname, libraries, ...
        commandLineOptions)
      if(nargin < 2)
        error('Not enough arguments, filename and classname is required');
      end
      
      if(nargin == 1)
        error([filename " does not exist"]);
      end
      
      % Check for commandLineOptions 
      if(nargin == 5)
        exp = ["setCommandLineOptions(""" commandLineOptions """)"];
        cmdExp = obj.sendExpression(exp);
        if(iscell(cmdExp) && strcmp(cmdExp{1}, "false"))
          disp(obj.sendExpression("getErrorString()"));
          return;
        end
      end
      
      filepath = strrep(filename, '\', '/');
      loadfilemsg = obj.sendExpression(["loadFile( """ filepath """)"]);
      if(iscell(loadfilemsg) && strcmp(loadfilemsg{1}, "false"))
        disp(obj.sendExpression("getErrorString()"));
        return;
      end
      
      % Check for libraries
      if(nargin > 3)
        for n = 1:length(libraries)
          if(isfile(libraries{n}))
            libmsg = obj.sendExpression(["loadFile( """ libraries{n} """)"]);
          else
            libmsg = obj.sendExpression(["[loadModel(" libraries{n} ")"]);
          end
          if(iscell(libmsg) && strcmp(libmsg{1}, "false"))
            disp(obj.sendExpression("getErrorString()"));
            return;
          end
        end
      end
      obj.filename = filename;
      obj.modelname = modelname;

      obj.mattempdir = strrep(tempname, '\', '/');
      mkdir(obj.mattempdir);
      obj.sendExpression(["cd(""" obj.mattempdir """)"]);
      obj.BuildModelicaModel();
    end
    
    function BuildModelicaModel(obj)
      buildModelResult = obj.sendExpression(["buildModel(" obj.modelname ")"]);
      
      if(isempty(buildModelResult{1}))
        disp(obj.sendExpression("getErrorString()"));
        return;
      end
      
      xmlpath = fullfile(obj.mattempdir, char(buildModelResult(2)));
      obj.xmlfile = strrep(xmlpath, '\', '/');
      obj.xmlparse();
    end
    
    function workdir = getWorkDirectory(obj)
      workdir = obj.mattempdir;
    end
    
    function xmlparse(obj)
      if(isfile(obj.xmlfile))
        xDoc = omxmlread(obj.xmlfile);
         h = waitbar(0, 'Reading DefaultExperiment...', ...
          'Name', 'OMOctave: xmlparse()');
         
        % DefaultExperiment
        allexperimentitems = ...
          xDoc.getElementsByTagName('DefaultExperiment');
        obj.simulationoptions.('startTime') = ...
          char(allexperimentitems.getAttribute(1, 'startTime'));
        obj.simulationoptions.('stopTime') = ...
          char(allexperimentitems.getAttribute(1, 'stopTime'));
        obj.simulationoptions.('stepSize') = ...
          char(allexperimentitems.getAttribute(1, 'stepSize'));
        obj.simulationoptions.('tolerance') = ...
          char(allexperimentitems.getAttribute(1, 'tolerance'));
        obj.simulationoptions.('solver') = ...
          char(allexperimentitems.getAttribute(1, 'solver'));
        
        % ScalarVariables
        allvaritem = xDoc.getElementsByTagName('ScalarVariable');
        N = allvaritem.getLength;
        t = tic;
        fields = {'name', 'isValueChangeable', 'description', ...
            'variability', 'causality', 'alias', 'aliasVariable'};
        for k = 1:N
          if(k ==1 || ~mod(k, round(N/100))) 
            frac = k/N;
            waitbar(frac, h, ['Reading ScalarVariables ' ...
              num2str(frac*100, '%.0f') '% [' num2str(k) '/' ...
              num2str(N) '] dt = ' num2str(toc(t), '%.1f') ' s...']);
            t = tic;
          end
          
          scalar = struct();
          item = allvaritem.item(k);
          [~, s_idx] = ismember(fields, item.attribute_keys);
          for i = 1:length(fields);
            if(s_idx(i))
              scalar.(fields{i}) = item.attributes(s_idx(i)).value;
            else
              scalar.(fields{i}) = [];
            end
          end
          
          if(length(item.children))
            sub = xDoc.item(item.children(1));
            if(strcmp(sub.tag, 'Real'))
              [~, s_idx] = ismember('start', sub.attribute_keys);
              if(s_idx)
                scalar.('value') = char(sub.attributes(s_idx).value);
              else
                scalar.('value') = '';
              end
            else
              scalar.('value') = '';
            end
          end
          
          % Check for variability parameter and add to parameter list
          if(obj.linearFlag == false)
            name = scalar.('name');
            value = scalar.('value');
            if(strcmp(scalar.('variability'), 'parameter'))
              try
                obj.parameterlist.(name) = value;
              catch ME
                createValidNames(obj, name, value, "parameter");
              end
            end
            
            % Check for variability continuous and add to continuous list
            if(strcmp(scalar.('variability'), 'continuous'))
              try
                obj.continuouslist.(name) = value;
              catch ME
                createValidNames(obj, name, value, "continuous");
              end
            end
            
            % Check for causality input and add to input list
            if(strcmp(scalar.('causality'), 'input'))
              try
                obj.inputlist.(name) = value;
              catch ME
                createValidNames(obj, name, value, "input");
              end
            end
            
            % Check for causality output and add to output list
            if(strcmp(scalar.('causality'), 'output'))
              try
                obj.outputlist.(name) = value;
              catch ME
                createValidNames(obj, name, value, "output");
              end
            end
          end
          
          if(obj.linearFlag == true)
            if(scalar.('alias') == "alias")
              name = scalar.('name');
              if(name(2) == 'x')
                obj.linearstates = [obj.linearstates, name(4:end-1)];
              end
              if(name(2) == 'u')
                obj.linearinputs = [obj.linearinputs, name(4:end-1)];
              end
              if(name(2) == 'y')
                obj.linearoutputs = [obj.linearoutputs, name(4:end-1)];
              end
            end
            obj.linearquantitylist = [obj.linearquantitylist, scalar];
          else
            obj.quantitieslist = [obj.quantitieslist, scalar];
          end
        end
        close(h);
      else
        error("xmlfile is not generated");
      end
    end
    
    function result = getQuantities(obj, args)
      if(nargin > 1)
        tmpresult = [];
        for n = 1:length(args)
          for q = 1:length(obj.quantitieslist)
            if(strcmp(obj.quantitieslist(q).name, args(n)))
              tmpresult = [tmpresult; obj.quantitieslist(q)];
            end
          end
        end
        result = tmpresult;
      else
        result = obj.quantitieslist;
      end
    end
    
    function result = getLinearQuantities(obj, args)
      if(nargin > 1)
        tmpresult = [];
        for n = 1:length(args)
          for q = 1:length(obj.linearquantitylist)
            if(strcmp(obj.linearquantitylist(q).name, args(n)))
              tmpresult = [tmpresult; obj.linearquantitylist(q)];
            end
          end
        end
        result = tmpresult;
      else
        result = obj.linearquantitylist;
      end
    end
    
    function result = getParameters(obj, args)
      if(nargin > 1)
        if(iscell(args))
          param = {};
          for n = 1:length(args)
            param{n} = obj.parameterlist.(args{n});
          end
        else
          param = obj.parameterlist.(args);
        end
        result = param;
      else
        result = obj.parameterlist;
      end
    end
    
    function result = getInputs(obj, args)
      if(nargin > 1)
        if(iscell(args))
          inputs = {};
          for n = 1:length(args)
            inputs{n} = obj.inputlist.(args{n});
          end
        else
          inputs = obj.inputlist.(args);
        end
        result = inputs;
      else
        result = obj.inputlist;
      end
    end
    
    function result = getOutputs(obj, args)
      if(nargin > 1)
        if(iscell(args))
          outputs = {};
          for n = 1:length(args)
            outputs{n} = obj.outputlist.(args{n});
          end
        else
          outputs = obj.outputlist.(args);
        end
        result = outputs;
      else
        result = obj.outputlist;
      end
    end
    
    function result = getContinuous(obj, args)
      if(nargin > 1)
        if(iscell(args))
          continuous = {};
          for n = 1:length(args)
            continuous{n} = obj.continuouslist.(args{n});
          end
        else
          continuous = obj.continuouslist.(args);
        end
        result = continuous;
      else
        result = obj.continuouslist;
      end
    end
    
    function result = getSimulationOptions(obj, args)
      if(nargin > 1)
        if(iscell(args))
          simoptions = {};
          for n = 1:length(args)
            simoptions{n} = obj.simulationoptions.(args{n});
          end
        else
          simoptions = obj.simulationoptions.(args);
        end
        result = simoptions;
      else
        result = obj.simulationoptions;
      end
    end
    
    function result = getLinearizationOptions(obj, args)
      if(nargin > 1)
        if(iscell(args))
          linoptions = {};
          for n = 1:length(args)
            linoptions{n} = obj.linearOptions.(args{n});
          end
        else
          linoptions = obj.linearOptions.(args);
        end
        result = linoptions;
      else
        result = obj.linearOptions;
      end
    end
    
    % Set Methods
    function setParameters(obj, args)
      if(nargin > 1)
        if(~iscell(args))
          args = {args};
        end
        for n = 1:length(args)
          val = strrep(args{n}, " ", "");
          value = strsplit(val, "=");
          if(isfield(obj.parameterlist, char(value{1})))
            obj.parameterlist.(value{1}) = value{2};
            obj.overridevariables.(value{1}) = value{2};
          else
             disp([value{1} " is not a parameter"]);
          end
        end
      end
    end
    
    function setSimulationOptions(obj, args)
      if(nargin > 1)
        if(~iscell(args))
          args = {args};
        end
        for n = 1:length(args)
          val = strrep(args{n}, " ", "");
          value = strsplit(val, "=");
          if(isfield(obj.simulationoptions, char(value{1})))
            obj.simulationoptions.(value{1}) = value{2};
            obj.simoptoverride.(value{1}) = value{2};
          else
            disp([value{1} " is not a Simulation Option"]);
          end
        end
      end
    end
    
    function setLinearizationOptions(obj, args)
      if(nargin > 1)
        if(~iscell(args))
          args = {args};
        end
        for n = 1:length(args)
          val = strrep(args{n}, " ", "");
          value = strsplit(val, "=");
          if(isfield(obj.linearOptions, char(value{1})))
            obj.linearOptions.(value{1}) = value{2};
            obj.linearOptions.(value{1}) = value{2};
          else
            disp([value{1} " is not a Linearization Option"]);
          end
        end
      end
    end
    
    function setInputs(obj, args)
      if(nargin > 1)
        if(~iscell(args))
          args = {args};
        end
        for n = 1:length(args)
          val = strrep(args{n}, " ", "");
          value = strsplit(val, "=");
          if(isfield(obj.inputlist, char(value{1})))
            obj.inputlist.(value{1}) = value{2};
            obj.inputflag = true;
          else
            disp([value{1} " is not a Input"]);
          end
        end
      end
    end
    
    function createcsvData(obj)
      obj.csvfile = strrep(fullfile(obj.mattempdir, ...
        [char(obj.modelname) '.csv']), '\', '/');
      fileID = fopen(obj.csvfile, "w");
      fprintf(fileID, ['time,' strjoin(fieldnames(obj.inputlist), ",") ...
        ',end\n']);
      fields = fieldnames(obj.inputlist);
      time = [];
      count = 1;
      tmpcsvdata = struct;
      
      for i = 1:length(fieldnames(obj.inputlist))
        var = obj.inputlist.(fields{i});
        if(isempty(var))
          var = "0";
        end
        s1 = eval(strrep(strrep(strrep(strrep(var, "[", "{"), ...
          "]", "}"), "(", "{"), ")", "}"));
        tmpcsvdata.(char(fields(i))) = s1;
        if(length(s1) > 1)
          for j = 1:length(s1)
            t = s1(j);
            time = [time, t{1}{1}];
            count = count+1;
          end
        end
      end
      
      if(isempty(time))
        time = [str2double(obj.simulationoptions.('startTime')), ...
          str2double(obj.simulationoptions.('stopTime'))];
      end
      
      t1 = struct2cell(tmpcsvdata);
      sortedtime = sort(time);
      previousvalue = struct;
      
      for t = 1:length(sortedtime)
        fprintf(fileID, [num2str(sortedtime(t)) ',']);
        listcount = 1;
        for i = 1:length(t1)
          tmp1 = t1{i};
          if(iscell(tmp1))
            found = false;
            for k = 1:length(tmp1)
              if(sortedtime(t) == tmp1{k}{1})
                data = tmp1{k}{2};
                fprintf(fileID, [num2str(data) ',']);
                pfieldname = ["x" char(listcount)];
                previousvalue.(pfieldname) = data;
                tmp1(k) = [];
                t1{i} = tmp1;
                found = true;
                break;
              end
            end
            if(found == false)
              tmpfieldname = ["x" char(listcount)];
              data = previousvalue.(tmpfieldname);
              fprintf(fileID, [num2str(data) ',']);
            end
          else
            fprintf(fileID, [num2str(t1{i}) ',']);
          end
          listcount = listcount+1;
        end
        fprintf(fileID, [num2str(0) '\n']);
      end
      fclose(fileID);
    end
    
    function simulate(obj, resultfile, simflags)
      if(nargin > 1)
        if(~isempty(resultfile))
          r = [' -r=' char(resultfile)];
          obj.resultfile=strrep(fullfile(obj.mattempdir, ...
            char(resultfile)), '\', '/');
        else
          r = '';
        end
      else
        r = '';
        obj.resultfile = strrep(fullfile(obj.mattempdir, ...
          [char(obj.modelname) '_res.mat']), '\', '/');
      end
      
      if(nargin > 2)
        simflags = [' ' char(simflags)];
      else
        simflags = '';
      end
      
      if(isfile(obj.xmlfile))
        if(ispc)
          getexefile = strrep(fullfile(obj.mattempdir, ...
            [char(obj.modelname) '.exe']), '\', '/');
        else
          getexefile = strrep(fullfile(obj.mattempdir, ...
            char(obj.modelname)), '\', '/');
        end
        
        curdir = pwd;
        if(isfile(getexefile))
          cd(obj.mattempdir);
          if(~isempty(fieldnames(obj.overridevariables)) || ...
           ~isempty(fieldnames(obj.simoptoverride)))
            names = [fieldnames(obj.overridevariables);...
              fieldnames(obj.simoptoverride)];
            tmpstruct = cell2struct([struct2cell( ...
              obj.overridevariables); ...
              struct2cell(obj.simoptoverride)], names, 1);
            fields = fieldnames(tmpstruct);
            tmpoverride1 = {};
            for i = 1:length(fields)
              if(isfield(obj.mappednames, fields{i}))
                name = obj.mappednames.(fields{i});
              else
                name = fields{i};
              end
              tmpoverride1{i} = [name "=" tmpstruct.(fields{i})];
            end
            overridevar = [' -override=' char(strjoin(tmpoverride1, ','))];
          else
            overridevar = '';
          end
          
          if(obj.inputflag == true)
            obj.createcsvData()
            csvinput = [' -csvInput=' obj.csvfile];
          else
            csvinput = '';
          end
          
          finalsimulationexe = [getexefile, overridevar, csvinput, ...
            r, simflags];
          system(finalsimulationexe);
        else
          disp("Model cannot be Simulated: executable not found")
        end
        cd(curdir)
      else
        disp("Model cannot be Simulated: xmlfile not found")
      end
    end
    
    function result = linearize(obj)
      linres = obj.sendExpression(...
        "setCommandLineOptions(""+generateSymbolicLinearization"")");
      if(iscell(linres) && strcmp(linres{1}, "false"))
        disp(["Linearization cannot be performed"...
          obj.sendExpression("getErrorString()")]);
        return;
      end

      fields = fieldnames(obj.overridevariables);
      tmpoverride1 = {};
      
      for i = 1:length(fields)
        tmpoverride1{i} = [fields{i} "=" ...
          obj.overridevariables.(fields{i})];
      end
      
      if(~isempty(tmpoverride1))
        tmpoverride2 = [' -override=', char(strjoin(tmpoverride1, ','))];
      else
        tmpoverride2 = "";
      end
      
      linfields = fieldnames(obj.linearOptions);
      tmpoverride1lin = {};
      for i = 1:length(linfields)
        tmpoverride1lin{i} = [linfields{i} "="...
          obj.linearOptions.(linfields{i})];
      end
      overridelinear = char(strjoin(tmpoverride1lin, ','));
      
      if(obj.inputflag == true)
        obj.createcsvData()
        csvinput = ['-csvInput=' obj.csvfile];
      else
        csvinput = "";
      end
      
      linexpr = strcat('linearize(', obj.modelname, ',', ...
        overridelinear, ',', 'simflags=', '"', ...
        csvinput, '  ', tmpoverride2, '")');
      res = obj.sendExpression(linexpr);
      obj.resultfile = res.("resultFile");
      obj.linearmodelname = strcat('linear_', obj.modelname);
      obj.linearfile = strrep(fullfile(obj.mattempdir, ...
        [char(obj.linearmodelname) '.mo']), '\', '/');
      if(isfile(obj.linearfile))
        loadmsg = obj.sendExpression(["loadFile(""" obj.linearfile """)"]);
        if(iscell(loadmsg) && strcmp(loadmsg{1}, "false"))
          disp(obj.sendExpression("getErrorString()"));
          return;
        end
        cNames = obj.sendExpression("getClassNames()");
        buildmodelexpr = ["buildModel(" cNames{1} ")"];
        buildModelmsg = obj.sendExpression(buildmodelexpr);
        if(~isempty(buildModelmsg{1}))
          obj.linearFlag = true;
          obj.xmlfile = strrep(...
            fullfile(obj.mattempdir, char(buildModelmsg(2))), '\', '/');
          obj.linearquantitylist = [];
          obj.linearinputs = "";
          obj.linearoutputs = "";
          obj.linearstates = "";
          obj.xmlparse();
          result = obj.getLinearMatrix();
        else
          disp(omc.sendExpression("getErrorString()"));
        end
      end
    end
    
    function result = getLinearMatrix(obj)
      matrix_A = struct;
      matrix_B = struct;
      matrix_C = struct;
      matrix_D = struct;
      
      for i = 1:length(obj.linearquantitylist)
        name = obj.linearquantitylist(i).("name");
        value = obj.linearquantitylist(i).("value");
        if(obj.linearquantitylist(i).("variability") == "parameter")
          if(name(1) == 'A')
            tmpname = matlab.lang.makeValidName(name);
            matrix_A.(tmpname) = value;
          end
          if(name(1) == 'B')
            tmpname = matlab.lang.makeValidName(name);
            matrix_B.(tmpname) = value;
          end
          if(name(1) == 'C')
            tmpname = matlab.lang.makeValidName(name);
            matrix_C.(tmpname) = value;
          end
          if(name(1) == 'D')
            tmpname = matlab.lang.makeValidName(name);
            matrix_D.(tmpname) = value;
          end
        end
      end
      
      FullLinearMatrix = {};
      tmpMatrix_A = getLinearMatrixValues(obj, matrix_A);
      tmpMatrix_B = getLinearMatrixValues(obj, matrix_B);
      tmpMatrix_C = getLinearMatrixValues(obj, matrix_C);
      tmpMatrix_D = getLinearMatrixValues(obj, matrix_D);
      FullLinearMatrix{1} = tmpMatrix_A;
      FullLinearMatrix{2} = tmpMatrix_B;
      FullLinearMatrix{3} = tmpMatrix_C;
      FullLinearMatrix{4} = tmpMatrix_D;
      result = FullLinearMatrix;
    end
    
    function result = getLinearMatrixValues(~, matrix_name)
      if(~isempty(matrix_name))
        fields = fieldnames(matrix_name);
        t = fields{end};
        rows = str2double(t(3));
        columns = str2double(t(5));
        tmpMatrix = zeros(rows, columns, 'double');
        for i = 1:length(fields)
          n = fields{i};
          r = str2double(n(3));
          c = str2double(n(5));
          val = str2double(matrix_name.(fields{i}));
          format shortG
          tmpMatrix(r, c) = val;
        end
        result = tmpMatrix;
      else
        result = 0;
      end
    end
    
    function result = getLinearInputs(obj)
      if(obj.linearFlag == true)
        result = obj.linearinputs;
      else
        disp("Model is not Linearized");
        result = false;
      end
    end
    
    function result = getLinearOutputs(obj)
      if(obj.linearFlag == true)
        result = obj.linearoutputs;
      else
        disp("Model is not Linearized");
        result = false;
      end
    end
    
    function result = getLinearStates(obj)
      if(obj.linearFlag == true)
        result = obj.linearstates;
      else
        disp("Model is not Linearized");
        result = false;
      end
    end
    
    function result = getSolutions(obj, args, resultfile)
      if(nargin > 2)
        resfile = char(resultfile);
      else
        resfile = obj.resultfile;
      end
      
      if(isfile(resfile))
        if(nargin > 1 && ~isempty(args))
          tmp1 = strjoin(cellstr(args), ',');
          tmp2 = ['{', tmp1, '}'];
          simresult = obj.sendExpression([ ...
            "readSimulationResult(""" resfile """," tmp2 ")"]);
          obj.sendExpression("closeSimulationResultFile()");
          result = simresult;
        else
          tmp = obj.sendExpression(["readSimulationResultVars(""" ...
            resfile """)"]);
          obj.sendExpression("closeSimulationResultFile()");
          result = tmp;
        end
      else
        result = ["Result File does not exist! " char(resfile)];
        disp(result);
      end
    end
    
    function createValidNames(obj, name, value, structname)
      % Function which creates valid field name as Octave
      % does not allow der(h) to be a valid name, also map
      % the changed names to mappednames struct, inorder to
      % keep track of the original names as it is needed to query
      % simulation results
      
      tmpname = matlab.lang.makeValidName(name);
      obj.mappednames.(tmpname) = name;
      if(strcmp(structname, 'continuous'))
        obj.continuouslist.(tmpname) = value;
      end
      if(strcmp(structname, 'parameter'))
        obj.parameterlist.(tmpname) = value;
      end
      if(strcmp(structname, 'input'))
        obj.inputlist.(tmpname) = value;
      end
      if(strcmp(structname, 'output'))
        obj.outputlist.(tmpname) = value;
      end
    end
    
    function result = parseExpression(obj, args)
      final = regexp(args, '"(.*?)"|[{}()=]|[a-zA-Z0-9_.]+', 'match');
      if(length(final) > 1)
        if(strcmp(char(final{1}), "{") && ~strcmp(char(final{2}), "{"))
          buff = {};
          count = 1;
          for i = 1:length(final)
            if(~any(ismember(char(final{i}), {"{", "}", ")", "(", ","})))
              value = strrep(final{i}, """", "");
              buff{count} = value;
              count = count+1;
            end
          end
          result = buff;
        elseif(strcmp(char(final{1}), "{") && strcmp(char(final{2}), "{"))
          buff = {};
          tmpcount = 1;
          count = 1;
          for i = 2:length(final)-1
            if(strcmp(char(final{i}), "{"))
              if(isnan(str2double(final{i+1})))
                tmp = "";
              else
                tmp = [];
              end
            elseif(strcmp(char(final{i}), "}"))
              buff{tmpcount} = tmp;
              tmp = {};
              count = 1;
              tmpcount = tmpcount+1;
            else
              tmp{count} = char(final{i});
              count = count+1;
            end
          end
          result = buff;
        elseif(strcmp(final{1}, "record"))
          result = struct;
          for i = 3:length(final)-2
            if(strcmp(char(final{i}), "="))
              value = strrep(final{i+1}, """", "");
              result.(final{i-1}) = value;
            end
          end
        elseif(strcmp(final{1}, "fail"))
          result = obj.sendExpression("getErrorString()");
        else
          result = strrep(args, """", "");
        end
      elseif(length(final) == 1)
        result = strrep(final, """", "");
      else
        result = strrep(args, """", "");
      end
    end
    
    function close(obj)
      delete(obj.portfile);
      if(obj.active)
        obj.active = false;
        zmq_close(obj.requester);
      end
      if(ispc && obj.pid > 0)
        system(["Taskkill /PID " obj.pid " /F  >nul 2>nul"]);
      end
      delete(obj);
    end
  end
  
  methods (Access = private)
    function pkgForgeCheck(obj, pkgFname, min_version)
      % GNU Octave forge package check
      % Author: Milos Petrasinovic <mpetrasinovic@prdc.rs>
      % PR-DC, Republic of Serbia
      % info@pr-dc.com
      % ----- INPUTS -----
      % pkgFname - name of forge package
      % min_version - version of package
      % --------------------

      fpkg = pkg('list', pkgFname);
      if(~isempty(fpkg)) 
        if(nargin > 1)
          if(compare_versions(fpkg{1}.version, min_version, '>='))
            if(~fpkg{1}.loaded)
              pkg('load', pkgFname);
            end
          else
            disp([' Wait for ' pkgFname ' package to be updated...']);
            pkg('update', pkgFname);
            pkg('load', pkgFname);
            disp(' Package is updated and loaded...');
          end
        else
          if(~fpkg{1}.loaded)
            pkg('load', pkgFname);
          end
        end
      else
        disp([' Wait for ' pkgFname ' package to be installed...']);
        try
          pkg('install', '-forge', pkgFname);
          pkg('load', pkgFname);
          disp(' Package is installed and loaded...');
        catch
          error('Package installation failed!');
        end
      end
    end
  end
end
