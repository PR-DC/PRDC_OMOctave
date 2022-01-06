% Class omxmlread
% Read OpenModelica xml file
% Author: Milos Petrasinovic <mpetrasinovic@prdc.rs>
% PR-DC, Republic of Serbia
% info@pr-dc.com
% ---------------

classdef omxmlread
  properties (Access = private)
    data;
    ids;
  end
  methods
    function obj = omxmlread(file)
      path = mfilename('fullpath');
      path = path(1:end-length(mfilename));
      addpath([path '\xml_parser']);
      obj.data = xml_parser(file);
      obj.ids = cell2mat({obj.data(:).id});
    end
    
    function val = getLength(obj)
      val = length(obj.ids);
    end
    
    function obj = getElementsByTagName(obj, tag, id)
      if(nargin > 2)
        ids = obj.data(id).children;
      else
        ids = obj.ids;
      end
      i = strcmp(tag, {obj.data(ids).tag});
      if(any(i))
        obj.ids = ids(i);
      else
        obj.ids = [];
      end
    end
    
    function val = item(obj,i)
      val = obj.data(obj.ids(i));
    end
    
    function val = getAttribute(obj, i, attribute)
      id = obj.ids(i);
      [i,j] = ismember(attribute, obj.data(id).attribute_keys);
      if(i)
        val = obj.data(id).attributes(j).value;
      else
        val = [];
      end
    end
  end
end

