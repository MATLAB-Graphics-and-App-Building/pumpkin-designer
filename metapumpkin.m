function [script_or_struct,MAP] = metapumpkin(opts)
% METAPUMPKIN - A script that generates a script to draw a pumpkin.
%
% Pumpkin Parameters:
%   Radius - Radius of the pumpkin
%   Height - Height of the pumpkin
%   Resolution - Density of the pumpkin mesh
%   NumBumps - Number of bumps or ridges around the pumpkin
%   BumpDepth - Depth of the bumps (relative to Radius)
%   SecondaryBumpDepth - Depth of secondary bumps.
%          This value is added to BumpDepth for primary bumps.
%   DimpleDepth - Depth of the dimple on the top/bottom of the pumpkin.
%
%   SpeckleSize - In the color field, how promenant are the speckles?
%          The larger the value, the more visible speckles there will be.
%
%   Colormap - The colormap to use for the pumpkin.  A named colormap, or
%          two colors that are linearly interpolated between.
%
%   StemStyle - A complex curved & ridgy stem, or a simple stem for shorter script.
%   StemRadius - 2 Radii for complex stem.
%   StemDims - Size of partial torus of complex stem.
%   StemColor - color of the stem.
%
%   ConstantFolding - Control how constants are integrated into the script.

% Copyright 2024 The MathWorks, Inc.

    arguments
        opts.Radius = 1 % diameter of pumpkin
        opts.Height = 1 % height of pumpkin
        opts.Resolution = 200 % density of pumpkin mesh.
        opts.NumBumps = 10 % number of ridges
        opts.BumpDepth = .1 % depth of bumps
        opts.SecondaryBumpDepth = .02 % include secondary bumps of this depth
        opts.DimpleDepth = .2 % depth of dimple under the stem

        opts.SpeckleSize = 0
        %opts.SpeckleColorRatio = .5
        %opts.SpeckleTransitionRatio = .1

        opts.Colormap = validatecolor({'#f06000' '#ff7518'},'multiple');

        opts.StemStyle = 'complex'
        opts.StemRadius = [ .06 .1 ]
        opts.StemDims = [ .4 .5 ]
        opts.StemColor = validatecolor('#008000')

        % Try to eliminate variables by folding values into code.  This makes the code
        % shorter and better for mini-hacks
        opts.ConstantFolding = false
    end

    if opts.NumBumps == 0
        % a bumpless pumpkin means we can't create the stem the fancy way.
        opts.StemStyle = 'simple';
    end

    SG = SimpleScriptGen("Pumpkin", 'constantfolding', opts.ConstantFolding);

    SG.constant("pr", opts.Radius, "Radius");
    SG.constant("ph", opts.Height, "Height")
    SG.constant("res", opts.Resolution, "Resolution");
    SG.constant("nb", opts.NumBumps, "Number of Bumps");
    SG.constant("bd", opts.BumpDepth, "Depth of Bumps");

    if opts.SecondaryBumpDepth ~= 0
        SG.constant("sbd", opts.SecondaryBumpDepth, "Depth of Secondary Bumps");
    end

    SG.constant("dd", opts.DimpleDepth, "Dimple (top/bottom) depth");

    if opts.SpeckleSize > 0
        SG.constant("ss", opts.SpeckleSize, "Speckle Size");
        % Use 2 color colormap, so these aren't needed (yet)
        %SG.constant("scr", opts.SpeckleColorRatio, "Speckle Color Ratio");
        %SG.constant("str", opts.SpeckleTransitionRatio, "Speckle Transition Ratio");
    end

    SG.constant("sr", flip(opts.StemRadius), "Stem Size (radius of tube)");
    SG.constant("sd", opts.StemDims, "Stem Dimensions (length of curve)");
    SG.constant("sc", rgb2hex(opts.StemColor), "Stem Color");

    if ~SG.constantfolding
        SG.addlines("");
        SG.addcomment("Generate initial sphere coordinates.", Header=true);
    end

    SG.addlines("[ Xs, Ys, Zs ] = sphere(" + SG.ref("res") + "-1);");

    if opts.BumpDepth > 0 && opts.NumBumps > 0
        useRxy = true;
        if opts.SecondaryBumpDepth == 0
            SG.addcomment("This specifies the pumpkin ridges.");
            SG.addlines("Rxy = (0-(1-mod(linspace(0," + SG.ref("nb") + " *2," + SG.ref('res') + ...
                        " ),2)).^2)*" + SG.ref('bd') + ";");
        else
            SG.addcomment("This specifies the pumpkin ridges and secondary ridges.");
            SG.addlines(["Rxy = (0-(1-mod(linspace(0," + SG.ref('nb') + "*2," + SG.ref('res') + ...
                         "),2)).^2)*" + SG.ref('bd') + " + ..."
                         "      (0-(1-mod(linspace(0," + SG.ref('nb') + "*4," + SG.ref('res') + ...
                         "),2)).^2)*" + SG.ref('sbd') + ";"]);
        end
    else
        useRxy = false;        
    end

    SG.addcomment("This adds a dimple in the top/bottom of the pumpkin.");
    SG.addlines("Rz  = (0-linspace(1,-1," + SG.ref('res') + ")'.^4)*" + SG.ref('dd') + ";");
    
    SG.addcomment("Compute the mesh");
    if useRxy
        SG.addlines([ "X = (" + SG.ref('pr') + "+Rxy).*Xs;"
                      "Y = (" + SG.ref('pr') + "+Rxy).*Ys;"
                      "Z = (" + SG.ref('pr') + "+Rz).*Zs.*(Rxy+1)*" + SG.ref('ph') + ";"
                      "C = hypot(hypot(X,Y)," + SG.ref('pr') + ".*Zs.*(Rxy+1));"]);
    else
        if opts.Radius ~= 1
            SG.addlines([ "X = " + SG.ref('pr') + "*Xs;"
                          "Y = " + SG.ref('pr') + "*Ys;"
                          "Z = (" + SG.ref('pr') + "+Rz).*Zs.*" + SG.ref('ph') + ";"
                          "C = hypot(hypot(X,Y)," + SG.ref('pr') + "*Zs);"]);
        else
            SG.addlines([ "X = Xs;"
                          "Y = Ys;"
                          "Z = (1+Rz).*Zs.*" + SG.ref('ph') + ";"
                          "C = hypot(hypot(X,Y),Zs);"]);
        end
    end

    if opts.SpeckleSize > 0
        SG.addcomment("Compute Speckles");
        SG.addlines([ "Cm = randn(" + SG.ref('res') + ");"
                      "Cm(Cm<.97&Cm>-.97) = 0;"
                      "C = max(min(C + Cm*" + SG.ref('ss') + ", max(C,[],'all')), min(C,[],'all'));"
                    ]);
    end

    SG.addlines("");
    SG.addcomment("Compute the stem", Header=true)
    switch lower(opts.StemStyle)
      case 'complex'
        % Stem part
        SG.addlines([ "rf = [ 1.5 1 .7 .7 .7 .7 .7 .7 ];"
                      "r = [ repmat(" + SG.ref('sr') + "',floor(" + SG.ref('nb') + "),1); " ...
                      + SG.ref('sr',1) + "];"
                      "[theta, phi] = meshgrid(linspace(0,pi/2,numel(rf))," + ...
                      "linspace(0,2*pi,numel(r)));"
                      "Xst = (" + SG.ref('sd',1) + "-cos(phi).*r.*rf).*cos(theta)-" + SG.ref('sd',1) + ";"
                      "Zst = (" + SG.ref('sd',2) + "-cos(phi).*r.*rf).*sin(theta) + " ...
                      + SG.ref('ph') + "-max(0," + SG.ref('dd') + "*" + SG.ref('ph') + ");"
                      "Yst = -sin(phi).*r.*rf;"
                    ]);
      case 'simple'
        SG.addlines([ "Xst = Xs*" + SG.ref('sr',1) + ";"
                      "Yst = Ys*" + SG.ref('sr',2) + ";"
                      "Zst = Zs*" + SG.ref('sd',2) + "+Z(end,1);" ]);
      otherwise
        error('Unknown Stem Style %s', opts.StemStyle);
    end
    
    % Plot just the pumpkin part
    SG.nextsection;

    SG.addcomment("Plot the Pumpkin & Stem", Header=true);
    SG.addlines([ "surf(X,Y,Z,C,'FaceColor','interp','EdgeColor','none','FaceLighting','g');"
                  "surface(Xst,Yst,Zst,[],'FaceColor'," + SG.ref('sc') + ",'EdgeColor','none','FaceLighting','f');"]);

    SG.addlines([ "daspect([1 1 1]);"
                  "camlight"
                  "material([.6 .9 .3 2 .5])" ]);

    % Setup colors
    SG.nextsection;

    SG.addcomment("Pumpkin Colormap",Header=true);
    if opts.SpeckleSize == 0
        SG.colormap(opts.Colormap, 256);
    else
        SG.colormap(opts.Colormap, 2);
    end

    % Determine what our output will be.
    if nargout == 0
        SG.eval();
    elseif nargout == 1
        % Return the script
        script_or_struct = SG.generatescript;
    else
        % Return a struct with the relevant data in it so we can update
        % the graphic in our app.
        eval(join(SG.geomscript,newline));
        
        script_or_struct.X = X;
        script_or_struct.Y = Y;
        script_or_struct.Z = Z;
        script_or_struct.C = C;

        script_or_struct.Xst = Xst;
        script_or_struct.Yst = Yst;
        script_or_struct.Zst = Zst;

        script_or_struct.Cst = opts.StemColor;
        
        MAP = SG.generatemap();
    end
end
