function buildOptickleSys(varargin)
%buildOptickleSys Pops-up a window containing an Optickle based subsystem for simulinkNB
    % buildOptickleSys(optName,fVecName,inputs,outputs)
    % ARGUMENTS
    % optName: a string giving the name of the optickle model object
    %          note: if the input and output ports are not provided, then
    %          the optickle model object must exist with this name in the 
    %          workspace where this function is called.
    % fVecName: a string giving the name of the frequency vector
    % OPTIONAL ARGUMENTS
    % inputs: a cell array of strings that define which optickle inputs
    %        (drives) will be used
    % outputs: a cell array of strings that define which optickle outputs
    %        (probes) will be used
    
    % this is the string that appears in the noise budget legend
    NOISEGROUP = 'Quantum Vacuum';
    
    narginchk(2,4);
    
    optName = varargin{1};
    fVecName = varargin{2};
    
    if nargin<4
        opt = evalin('caller',optName);
        probearray = opt.probe;
        
        outputs = cell(length(probearray),1);
        for j =1:length(probearray)
            outputs{j} = probearray(j).name; 
        end
    else
        outputs = varargin{4};
    end
    
    if nargin<3
        inputs = getDriveNames(opt);
    else
        inputs = varargin{3};
    end

    % settings for placement of blocks
    origin.Inport = [20 50 50 70];
    offset.Inport = [0 100 0 100];
    origin.opt = [200 20 500 600];
    origin.optInport = origin.Inport;
    offset.optInport = offset.Inport;
    origin.Outport = [800 50 830 70];
    offset.Outport = offset.Inport;
    origin.optOutport = origin.Outport;
    offset.optOutport = offset.Outport;
    origin.noiseBlock = origin.Outport - [150 50 150 50];
    offset.noiseBlock = offset.Outport;
    origin.internalDummy = [350 200 450 250];
    origin.internalMux = [275 25 300 425];
    origin.internalDemux = [500 25 525 425];
    origin.outputSum = [700 50 720 70];
    offset.outputSum = offset.Outport;
    
    % names
    base = 'simulinkNBOptickleBlock';
    sys = [base '/OptickleModel'];
    dummyName = 'opticalSystem';
    muxName = 'mux';
    demuxName = 'demux';
    
    try
        new_system(base)
    catch exception
        if exist(base,'file') == 4
            close_system(base,0)
            new_system(base)
        else
            rethrow(exception)
        end
    end
    sysblock = add_block('built-in/SubSystem',sys,'Position',origin.opt,'BackGroundColor','purple');
    set(sysblock,'AttributesFormatString','%<Description>');
    
    % argument string for autogenerated tag
    argstring = ['''' optName ''',''' fVecName ''''];
    if nargin > 2
        argstring = [argstring ',' makeCellLiteralString(inputs)];
    end
    if nargin > 3
        argstring = [argstring ',' makeCellLiteralString(outputs)];
    end
    set(sysblock,'Description',['Autogenerated using buildOptickleSys(' argstring ')']);
    
    
    % add the optickleFrd block
    optFrd = add_block('built-in/SubSystem',[sys '/' optName]);
    set(optFrd,'Position',origin.opt);
    set(optFrd,'AttributesFormatString','%<Description>');
    set(optFrd,'Description',['flexTF: optickleFrd(' optName ',' fVecName ')']);
    
    % add internal dummy system
    dummyBlock = add_block('cstblocks/LTI System',[sys '/' optName '/' dummyName]);
    set(dummyBlock,'Position',origin.internalDummy);
    set_param([sys '/' optName '/' dummyName],'sys',['repmat(tf(1),[' num2str(length(outputs)) ',' num2str(length(inputs)) '])']);
    %set(dummyBlock,
    mux = add_block('built-in/Mux',[sys '/' optName '/' muxName]);
    set(mux,'Position',origin.internalMux);
    set(mux,'Inputs',num2str(length(inputs)));
    demux = add_block('built-in/Demux',[sys '/' optName '/' demuxName]);
    set(demux,'Position',origin.internalDemux);
    set(demux,'Outputs',num2str(length(outputs)));
    add_line([sys '/' optName],[muxName '/1'],[dummyName '/1']);
    add_line([sys '/' optName],[dummyName '/1'],[demuxName '/1']);

    % loop on inputs
    for jj = 1:length(inputs);
        input = inputs{jj};
        % inputs
        add_block('built-in/Inport',[sys '/' input],'Position',origin.Inport+(jj-1)*offset.Inport);
        % optickleFrd inputs
        add_block('built-in/Inport',[sys '/' optName '/' input],'Position',origin.optInport+(jj-1)*offset.optInport);
        
        % add links
        add_line(sys,[input '/1'],[optName '/' num2str(jj)],'autorouting','on');
        add_line([sys '/' optName],[input '/1'],[muxName '/' num2str(jj)],'autorouting','on');
    end
    
    % loop on outputs
    for jj = 1:length(outputs);
        output = outputs{jj};
        % outputs
        add_block('built-in/Outport',[sys '/' output],'Position',origin.Outport+(jj-1)*offset.Outport);
        % optickleFrd outputs
        add_block('built-in/Outport',[sys '/' optName '/' output],'Position',origin.optOutport+(jj-1)*offset.optOutport);
        
        % add the noiseblock
        noiseBlock = add_block('NbLibrary/NbNoiseSource',[sys '/' output '_Noise']);
        set(noiseBlock,'Position',origin.noiseBlock+(jj-1)*offset.noiseBlock);
        set(noiseBlock,'asd',['optickleNoiseBlock(' optName ',' fVecName ',''' output ''','...
            'makeOptickleDriveIndex(' optName ',' makeCellLiteralString(inputs) '))'])
        set(noiseBlock,'groupNest','2');
        set(noiseBlock,'group',['''' NOISEGROUP '''']);
        set(noiseBlock,'subgroup',['''' output '''']);
        
        % add sum block to add noise to output
        sumblock = add_block('built-in/Sum',[sys '/Sum' num2str(jj)]);
        set(sumblock,'Position',origin.outputSum + (jj-1)*offset.outputSum);
        set(sumblock,'IconShape','round');
        set(sumblock,'Inputs','++|');
        
        % add links
        add_line([sys '/' optName],[demuxName '/' num2str(jj)],[output '/1'],'autorouting','on');
        add_line(sys,[output '_Noise/1'],['Sum' num2str(jj) '/1'],'autorouting','on');
        add_line(sys,[optName '/' num2str(jj)],['Sum' num2str(jj) '/2'],'autorouting','on');
        add_line(sys,['Sum' num2str(jj) '/1'],[output '/1'],'autorouting','on');
    end

    open_system(base);
    
end

function outputString = makeCellLiteralString(inputCell)
    
    outputString = '{';
    for jj = 1:length(inputCell)
        outputString = [outputString '''' inputCell{jj} ''',']; %#ok<AGROW>
    end
    outputString = [outputString(1:end-1) '}'];

end