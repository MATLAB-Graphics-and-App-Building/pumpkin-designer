classdef SimpleScriptGen < handle
% Class for generating scripts that compute geometry and draw graphics.
%
% These scripts are designed for use with creating bits of art
% that are previewed in app designer.
%
% To support this case the script is divided into these 3 parts:
%   geom script - part that computs geometry to use
%   gfx script - part that creates graphics objects
%   color script - part that creates and sets colormaps
%
% This lets the application generate geometry script and run it to get the
% desired geometry without creating graphics.  Alternately, the entire script
% can be run to create a graphic directly.
%
% See associated meta script with this app for sample use case.

% Copyright 2024 The MathWorks, Inc.

    properties
        % Script Part
        geomscript (:,1) string = []
        gfxscript (:,1) string = []
        % Modes
        constantfolding (1,1) logical = false
        % Constant Tracking
        constants (:,1) struct
    end

    properties (SetAccess=private)
        mode = "geom"
    end

    methods
        function SSG = SimpleScriptGen(headercomment)
            arguments
                headercomment = []
            end
            SSG.geomscript = headercomment;
        end

        function nextsection(SSG)
        % Switch script-gen to next section of the script.
            switch SSG.mode
              case "geom"
                SSG.mode = "gfx";
              case "gfx"
                SSG.mode = "color";
              otherwise
                error('no next mode');
            end
        end

        function addlines(SSG, lines)
        % Add various lines of code to current script
            switch SSG.mode
              case "geom"
                SSG.geomscript = [ SSG.geomscript
                                   lines ];
              case "gfx"
                SSG.gfxscript = [ SSG.gfxscript
                                   lines ];                
              case "color"
                error("Don't add lines to color section, Use colormap method instead.");
              otherwise
                error('no next mode');
            end
        end

        function constant(SSG, varname, value, comment)
        % Add a constant into this script.
        % If constant folding is off, add line to script.
        % If constant folding is on, add no script parts, just remember the constant.
            if SSG.constantfolding
            else
                if nargin >= 4
                    cstr = " %" + comment;
                else
                    cstr = "";
                end
                SSG.addlines(varname + "=" + SSG.toStr(value) + ";" + cstr);
            end
            CS.name = string(varname);
            CS.value = value;
            if isempty(SSG.constants)
                SSG.constants = CS;
            else
                SSG.constants(end+1) = CS;
            end
        end

        function str = ref (SSG, const, subsref)
        % Return script text referencing the constant variable CONST.
        % If constant folding is off, return variable name.
        % If constant folding is on, return the value as a string.
        %
        % Optional SUBSREF indicates if a refernce index is needed
        % when accessing the variable or value.
            arguments
                SSG
                const
                subsref (:,1) double = []
            end
            
            if SSG.constantfolding
                CS = SSG.conststruct(const);
                if ~isempty(subsref)
                    str = SSG.toStr(CS.value(subsref));
                else
                    str = SSG.toStr(CS.value);
                end
            else
                if ~isempty(subsref)
                    str = const + "(" + subsref + ")";
                else
                    str = const;
                end
            end
        end
    end

    %% Handle Colormp specification.
    %
    % Support either returning generated script, or computed colormap values.
    properties
        colormapscript
        colormapvaluescript
        namedmap
    end
    methods
        function colormap(SSG, colormap_specifier, cmapsize)
        % Handle script generation of a custom colormap.
        % A colormap_specifier can be a string, the name of a colormap like parula,
        % or it can be a pair of RGB colors.
        % If colors are passed in, the script fabricates a linearly interpolated colormap.
        %
        % Optional cmapsize controls how big the generated colormap should be.
            
            if ischar(colormap_specifier) || isstring(colormap_specifier)
                SSG.colormapscript = "colormap(gca," + colormap_specifier + "(" + cmapsize + "));";
                SSG.colormapvaluescript = "map = " + colormap_specifier + "(" + cmapsize + ");";
                SSG.namedmap = true;
            else
                vc = validatecolor(colormap_specifier,'multiple');
                if size(vc,1) == 2
                    SSG.colormapvaluescript = [ "map = [ linspace(" + vc(1,1) + "," + vc(2,1) + "," + cmapsize + ");"
                                                "        linspace(" + vc(1,2) + "," + vc(2,2) + "," + cmapsize + ");"
                                                "        linspace(" + vc(1,3) + "," + vc(2,3) + "," + cmapsize + ")]';"];
                    SSG.colormapscript = "colormap(gca,map);";
                    SSG.namedmap = false;
                else
                    error('Colormap can be either a colormap name, or 2 colors');
                end
            end
        end
    end

    %% Value Generation
    methods (Access=private)
        function str = toStr(~, value)
        % Convert some VALUE into a string to be inserted into a script.
            if ischar(value) || isstring(value)
                str = """" + string(value) + """";
            elseif isnumeric(value)
                if isscalar(value)
                    str = "" + value;
                elseif isvector(value)
                    str = "[" + join(string(value), " ") + "]";
                else
                    error("Don't know how to stringify value numbers of size %s,%s", size(value));
                end
            else
                error("Don't know how to stringify value of class %s", class(value));
            end
        end

        function CS = conststruct(SSG, name)
            cn = [ SSG.constants.name ];
            mask = strcmp(cn, name);
            CS = SSG.constants(mask);
        end
    end

    %% Final script generation OR execution
    methods
        function eval(SSG)
        % Evaluate the generated script.
            eval(join(SSG.geomscript,newline));
            eval(join(SSG.gfxscript,newline));
            if ~SSG.namedmap
                eval(join(SSG.colormapvaluescript,newline));
            end
            eval(join(SSG.colormapscript,newline));
        end

        function SCRIPT = generatescript(SSG)
        % Return the generated script.
            geom = join(SSG.geomscript,newline);
            gfx = join(SSG.gfxscript,newline);
            if ~SSG.namedmap
                cmapv = join(SSG.colormapvaluescript,newline) + newline;
            else
                cmapv = "";
            end
            cmap = join(SSG.colormapscript,newline);
            SCRIPT = geom + newline + gfx + newline + cmapv + cmap;
        end

        function map = generatemap(SSG)
        % Evaluate the color part of the script, and return the colormap.
            eval(join(SSG.colormapvaluescript,newline));
            map = map; %#ok
        end
    end
end
