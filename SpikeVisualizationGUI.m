function varargout = SpikeVisualizationGUI(varargin)
% MATLAB code for SpikeVisualizationGUI.fig
% Last Modified by GUIDE v2.5 25-Sep-2017 09:59:21
% version 0.5 (sept 2016), tested in R2014b
% Vincent Prevosto
% email: vp35 at duke.edu

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @SpikeVisualizationGUI_OpeningFcn, ...
    'gui_OutputFcn',  @SpikeVisualizationGUI_OutputFcn, ...
    'gui_LayoutFcn',  [] , ...
    'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT

%% --- Executes just before SpikeVisualizationGUI is made visible.
function SpikeVisualizationGUI_OpeningFcn(hObject, ~, handles, varargin)

% Choose default command line output for SpikeVisualizationGUI
handles.output = hObject;

if ~isempty(varargin)
    handles=CatStruct(handles,varargin{:}); % CatStruct available here:
    % http://www.mathworks.com/matlabcentral/fileexchange/7842-CatStruct
    
    if isfield(handles,'fname')
        set(handles.TB_FileName,'string',handles.fname(1:end-4));
    else
        set(handles.TB_FileName,'string','');
    end
    if isempty(handles.spikeFile)
        % check if spike sorting results are present in export folder
        cd(handles.exportDir);
        listExportDir=dir;
        listExportDir=listExportDir(cellfun('isempty',cellfun(@(x) strfind('.',x(end)),{listExportDir.name},'UniformOutput',false)));
        spikeFileIdx=cellfun(@(x) contains(x,'_spikes.mat'),{listExportDir.name});
        if logical(sum(spikeFileIdx))
            handles.spikeFile=listExportDir(spikeFileIdx).name;
        else %maybe spike sorting results are sub folder
            spikeSortingFolderIdx=[listExportDir.isdir];
            spikeSortingFolder=[handles.exportDir filesep listExportDir(spikeSortingFolderIdx).name];
            listSpikeSortingFolder=dir(spikeSortingFolder);
            spikeFileIdx=cellfun(@(x) contains(x,'result'),{listSpikeSortingFolder.name});
            if logical(sum(spikeFileIdx))
                handles.exportDir=spikeSortingFolder;
                handles.spikeFile=listSpikeSortingFolder(spikeFileIdx).name;
            else
                % ask user to select file to load
                [handles.spikeFile,handles.exportDir] = uigetfile({'*.mat;*.hdf5','Export Formats';...
                    '*.dat','Raw data';'*.*','All Files' },'Select data to load',cd);
                if handles.spikeFile==0
                    handles=rmfield(handles,'spikeFile');
                    handles.exportDir=cd;
                end
            end
        end
    end
else
    userinfo=UserDirInfo;
    %% get most recently changed data folder (looks for a folder named "export")
    exportDir=regexprep(userinfo.directory,'\\\w+$','\\export');
    dataDirListing=dir(exportDir);
    if ~isempty(dataDirListing)
        %removing dots
        dataDirListing=dataDirListing(cellfun('isempty',cellfun(@(x) strfind(x,'.'),...
            {dataDirListing.name},'UniformOutput',false)));
        %removing other folders
        dataDirListing=dataDirListing(cellfun('isempty',cellfun(@(x)...
            regexp('list | all | unwanted | folders | here ',x),...
            {dataDirListing.name},'UniformOutput',false)));
        [~,fDateIdx]=sort([dataDirListing.datenum],'descend');
        recentDataFolder=[exportDir filesep dataDirListing(fDateIdx(1)).name filesep];
    else
        recentDataFolder=cd;
    end
    
    % ask user to select file to load
    [handles.spikeFile,handles.exportDir] = uigetfile({'*.mat;*.hdf5','Export Formats';...
        '*.dat','Raw data';'*.*','All Files' },'Select data to load',recentDataFolder);
    if handles.spikeFile==0
        handles.spikeFile='';
        handles.exportDir=recentDataFolder;
    end
end
%define figure colormap
colormapSeed=colormap(lines);
handles.cmap=[colormapSeed(1:7,:);(colormapSeed+flipud(colormap(copper)))/2];

if isfield(handles,'spikeFile') && ~isempty(handles.spikeFile) && sum(strfind(handles.spikeFile,'.dat'))
    GetSortedSpikes_PB_Callback(hObject, handles);
end
handles.fileLoaded=0;
%create classification table
handles.classification = table([],[],[],categorical(),{},'VariableNames',{'SortID','Channel','UnitNumber','Classification','Comment'});

if isfield(handles,'spikeFile')
    handles=LoadSpikes(handles);
    handles=LoadRawData(handles);
end
% Update handles structure
guidata(hObject, handles);

%% --- Executes (conditional) at startup and on button press in GetSortedSpikes_PB.
function GetSortedSpikes_PB_Callback(hObject, ~, handles)
if ~isfield(handles,'datFile')
    handles.datFile=[cell2mat(regexp(handles.spikeFile,'.+(?=\_\w+\_\w+\.)','match')) '_nopp'];
end
[status,cmdout]=RunSpykingCircus(cd,handles.datFile,{'runspkc,exportspikes'});
if handles.GetSortedSpikes_PB.ForegroundColor(1)==0.3490
    handles.GetSortedSpikes_PB.ForegroundColor=[0.2 0.5 0.7];
else
    handles.GetSortedSpikes_PB.ForegroundColor=[0.3490 0.2000 0.3294];
end

%% Load data function
function handles=LoadSpikes(handles)
if isfield(handles,'subset')
    handles = rmfield(handles,'subset');
end
% if isfield(handles,'spikeFile')
%     handles = rmfield(handles,'spikeFile');
% end
if isfield(handles,'offlineSort_SpikeFile')
    handles = rmfield(handles,'offlineSort_SpikeFile');
end
% function declaration
axis_name= @(x) sprintf('Chan %.0f',x);

if isfield(handles,'fname') && strcmp(handles.fname,'')
    set(handles.TB_FileName,'string','')
else
    if ~isfield(handles,'fname') && isfield(handles,'rec_info')
        try
            handles.fname=handles.rec_info.exportname;
        catch
            handles.fname=handles.datFile;
        end
    end
    if handles.fileLoaded==0 & strfind(handles.spikeFile,'Resorted.mat')
        cd(handles.exportDir);
        spikeData=load(handles.spikeFile);
        handles = rmfield(handles,{'spikeFile','exportDir'});
        if isfield(handles,'rec_info')
            handles = rmfield(handles,'rec_info');
        end
        if isfield(handles,'Spikes')
            handles = rmfield(handles,'Spikes');
        end
        handles=CatStruct(handles,spikeData);
        clear spikeData;
    elseif handles.fileLoaded==0
        %% load spike data from matlab export, if exists
        cd(handles.exportDir);
        exportDirListing=dir;
        if isempty({exportDirListing(~cellfun('isempty',cellfun(@(x) strfind(x,'_spikes.'),...
                {exportDirListing.name},'UniformOutput',false))).name})
            handles.offlineSort_SpikeDir=handles.exportDir;
            handles.offlineSort_SpikeFile=handles.spikeFile;
            %go one folder up
            exportDirUp=handles.exportDir(1:regexp(handles.exportDir,'\\\w+\\$'));
            exportDirListing=dir(exportDirUp);
            handles.spikeFile={exportDirListing(~cellfun('isempty',cellfun(@(x) strfind(x,'_spikes.'),...
                {exportDirListing.name},'UniformOutput',false))).name};
            if ~isempty(handles.spikeFile)
                handles.exportDir=exportDirUp;
                cd(handles.exportDir);
            end
        end
        %         if ~isfield(handles,'fname') && isfield(handles,'offlineSort_SpikeFile')
        %             handles.fname=regexp(handles.offlineSort_SpikeFile,'.+?(?=\.)','match');
        %             handles.fname=handles.fname{1};
        %         end
        if iscell(handles.spikeFile) && size(handles.spikeFile,2)>1
            % ask which export file is the good one
            [whichOne,status] = listdlg('PromptString','Select correct spike file:',...
                'SelectionMode','single',...
                'ListString',handles.spikeFile);
            if status==1
                handles.spikeFile=handles.spikeFile{whichOne};
            else
                handles.spikeFile=[];
            end
            
            %             nameComp=cellfun(@(name) sum(ismember(handles.fname(1:end-4),...
            %                 name(1:size(handles.fname(1:end-4),2)))) ,handles.spikeFile);
            %             if abs(diff(nameComp))<2 %that can be tricky for some files
            %                 %select the most recent
            %                 fileDates=datenum({exportDirListing(~cellfun('isempty',cellfun(@(x) strfind(x,'_spikes.'),...
            %                     {exportDirListing.name},'UniformOutput',false))).date});
            %                 handles.spikeFile=handles.spikeFile{fileDates==max(fileDates)};
            %             else
            %                 handles.spikeFile=handles.spikeFile{nameComp==max(nameComp)};
            %             end
        else
            if iscell(handles.spikeFile)
                try
                    handles.spikeFile=handles.spikeFile{:};
                catch
                    handles.spikeFile=[];
                end
            end
        end
        %     end
        %     handles.exportDir='C:\Data\export\PrV75_61_optostim2_BR_6Ch_SyncCh_CAR';
        %     cd(handles.exportDir);
        %     handles.spikeFile='PrV75_61_optostim2_BR_6Ch_SyncCh_CAR_Ch3.mat';
        set(handles.TB_FileName,'string',[handles.exportDir handles.spikeFile])
        
        %% Load spike data
        if ~isempty(handles.spikeFile) && ~get(handles.Spikes_PrevSorted_RB,'value')
            spikeData=load(handles.spikeFile);
            if isfield(handles,'Spikes')
                % This will delete all Spikes data inlcuding any changes to HandSort
                % Might want to change that in future version
                handles = rmfield(handles,'Spikes');
            end
            handles=CatStruct(handles,spikeData);
            %clear
            clear spikeData;
        end
        % check if we need to load recording info
        if ~isfield(handles,'rec_info')
            try
                if ~isempty(handles.spikeFile)
                    fileName=regexp(handles.spikeFile,'.+(?=_\w+.mat$)','match');
                elseif ~isempty(handles.offlineSort_SpikeFile)
                    fileName=regexp(handles.offlineSort_SpikeFile,'.+(?=\.\w+\.\w+$)','match');
                    cd ..
                end
                recInfo=load([fileName{:} '_info.mat']);
            catch
                [fileInfoName,fileInfoDir,FilterIndex] = uigetfile({'*.mat;*.txt','File Info Formats';...
                    '*.*','All Files' },'Select file providing basic recording info, or cancel and enter info');
                if FilterIndex==0 % display prompt
                    prompt={'Sampling rate',...
                        'Number of channels in spike-sorted file',...
                        'uV/bit'};
                    name='Data file information';
                    numlines=1;
                    defaultanswer={'30000','32','0.25'};
                    options.Resize='on';
                    options.WindowStyle='normal';
                    info=inputdlg(prompt,name,numlines,defaultanswer,options);
                    info=cellfun(@(field) str2double(field),info,'UniformOutput',false);
                    info{2}=1:info{2};
                    recInfo.rec_info=cell2struct(info, {'samplingRate','exportedChan','bitResolution'}, 1);
                else
                    recInfo=load(fullfile(fileInfoDir,fileInfoName));
                end
            end
            % just in case the field is named differently
            field = fieldnames(recInfo);
            if ~strcmp(field{:},'rec_info')
                [recInfo.('rec_info')] = recInfo.(field{:});
                recInfo = rmfield(recInfo,field);
            end
            %concatenate
            if isfield(handles,'rec_info')
                handles = rmfield(handles,'rec_info');
            end
            handles=CatStruct(handles,recInfo);
            %clear
            clear recInfo;
        end
        if isfield(handles,'offlineSort_SpikeFile')
            if logical(regexp(handles.offlineSort_SpikeFile,'Ch\d+.')) % Spike2
                cd(handles.offlineSort_SpikeDir);
                handles.Spikes.Offline_Sorting=LoadSpikeData(handles.offlineSort_SpikeFile,...
                    handles.rec_info.numRecChan,handles.rec_info.samplingRate);
            elseif logical(regexp(handles.offlineSort_SpikeFile,'.hdf5')) % Spyking-Circus
                % first load raw traces in memory
                fileName=regexp(handles.offlineSort_SpikeFile,'.+(?=\.\w+\.\w+$)','match');
                %                 tb_filename=[tb_filename{1} '.dat'];
                if ~exist([fileName{:} '.dat'],'file') && ~exist([fileName{:} '.mat'],'file')
                    % try one folder up
                    cd ..
                end
                if ~exist([fileName{:} '.dat'],'file') && ~exist([fileName{:} '.mat'],'file')
                    % then ask where it is
                    [handles.datFile,handles.datDir] = uigetfile({'*.dat;*.mat','Data Formats';...
                        '*.*','All Files' },'Select data file for spike waveform extraction');
                else
                    if exist([fileName{1} '.dat'],'file')
                        handles.datFile=[fileName{1} '.dat'];
                    elseif exist([fileName{1} '.mat'],'file')
                        handles.datFile=[fileName{1} '.mat'];
                    end
                    handles.datDir=cd;
                end
                if strfind(handles.datFile,'.mat') % .mat file contain rawData
                    load(handles.datFile);
                elseif strfind(handles.datFile,'.dat')
                    rawData = memmapfile(fullfile(handles.datDir,handles.datFile),'Format','int16');
                end
                %% then import spike Data
                cd(handles.offlineSort_SpikeDir);
                if ~isfield(handles.rec_info,'bitResolution') || isempty(handles.rec_info.bitResolution)
                    handles.rec_info.bitResolution=0.25; %default 0.25 bit per uV
                end
                handles.Spikes.Offline_Sorting=LoadSpikeData(handles.offlineSort_SpikeFile,rawData,...
                    numel(handles.rec_info.exportedChan),handles.rec_info.samplingRate,handles.rec_info.bitResolution); %handles.rawDataInfo.size(1)
                clear rawData;
            elseif logical(regexp(handles.offlineSort_SpikeFile,'rez.mat')) % KiloSort
                fileName=regexp(handles.offlineSort_SpikeFile,'.+?(?=\.)','match');
                %                 tb_filename=[tb_filename{1} '.dat'];
                if ~exist([fileName{1} '.dat'],'file') ||  ~exist([fileName{1} '.mat'],'file') % then ask where it is
                    [handles.datFile,handles.datDir] = uigetfile({'*.dat;*.mat','Data Formats';...
                        '*.*','All Files' },'Select data file for spike waveform extraction');
                else
                    if exist([fileName{1} '.dat'],'file')
                        handles.datFile=[fileName{1} '.dat'];
                    elseif exist([fileName{1} '.mat'],'file')
                        handles.datFile=[fileName{1} '.mat'];
                    end
                    handles.datDir=cd;
                end
                if strfind(handles.datFile,'.mat') % .mat file contain rawData
                    load(handles.datFile);
                elseif strfind(handles.datFile,'.dat')
                    rawData = memmapfile(fullfile(handles.datDir,handles.datFile),'Format','int16');
                end
                %then import
                cd(handles.offlineSort_SpikeDir);
                if ~isfield(handles.rec_info,'bitResolution') || isempty(handles.rec_info.bitResolution)
                    handles.rec_info.bitResolution=0.25; %default 0.25 uV/bit
                end
                handles.Spikes.Offline_Sorting=LoadSpikeData(handles.offlineSort_SpikeFile,rawData,...
                    numel(handles.rec_info.exportedChan),handles.rec_info.samplingRate,handles.rec_info.bitResolution); %handles.rawDataInfo.size(1)
                clear rawData;
            end
            cd(handles.exportDir);
        end
        if get(handles.Spikes_Th_RB,'value')
            %extract waveforms if needed
            if ~isfield(handles.Spikes.Offline_Threshold,'Waveforms')
                % first load raw traces
                fileName=regexp(handles.spikeFile,'.+(?=_\w+.\w+$)','match');
                load([fileName{:} '_raw.mat']);
                %then import
                handles.Spikes=LoadSpikeData(handles.spikeFile,...
                    handles.Spikes.Offline_Threshold.electrode,...
                    handles.Spikes.Offline_Threshold.samplingRate(:,1),rawData);
                clear rawData
            end
        end
        
        if isfield(handles.Spikes,'HandSort')
            % all good
        elseif isfield(handles.Spikes,'Online_Sorting') || isfield(handles.Spikes,'Offline_Sorting') ...
                || isfield(handles.Spikes,'Offline_Threshold')
            if isfield(handles.Spikes,'Offline_Threshold') && get(handles.Spikes_Th_RB,'value')
                set(handles.Spikes_SortOff_RB,'value',0);
                set(handles.Spikes_SortOn_RB,'value',0);
                handles.Spikes.HandSort.Units=handles.Spikes.Offline_Threshold.Units;
                handles.Spikes.HandSort.SpikeTimes=handles.Spikes.Offline_Threshold.SpikeTimes;
                handles.Spikes.HandSort.Waveforms=handles.Spikes.Offline_Threshold.Waveforms;
                handles.Spikes.HandSort.samplingRate=handles.Spikes.Offline_Threshold.samplingRate;
            elseif isfield(handles.Spikes,'Offline_Sorting') || get(handles.Spikes_SortOff_RB,'value')
                set(handles.Spikes_SortOff_RB,'value',1);
                set(handles.Spikes_SortOn_RB,'value',0);
                handles.Spikes.HandSort.Units=handles.Spikes.Offline_Sorting.Units;
                handles.Spikes.HandSort.SpikeTimes=handles.Spikes.Offline_Sorting.SpikeTimes;
                handles.Spikes.HandSort.Waveforms=handles.Spikes.Offline_Sorting.Waveforms;
                handles.Spikes.HandSort.samplingRate=handles.Spikes.Offline_Sorting.samplingRate;
            elseif isfield(handles.Spikes,'Online_Sorting') || get(handles.Spikes_SortOn_RB,'value')
                set(handles.Spikes_SortOff_RB,'value',0);
                set(handles.Spikes_SortOn_RB,'value',1);
                handles.Spikes.HandSort.Units=handles.Spikes.Online_Sorting.Units;
                handles.Spikes.HandSort.SpikeTimes=handles.Spikes.Online_Sorting.SpikeTimes;
                handles.Spikes.HandSort.Waveforms=handles.Spikes.Online_Sorting.Waveforms;
                handles.Spikes.HandSort.samplingRate=handles.Spikes.Online_Sorting.samplingRate;
            end
            % set data classes
            handles.Spikes.HandSort.SpikeTimes=...
                cellfun(@(spktimes) uint32(spktimes), handles.Spikes.HandSort.SpikeTimes,'UniformOutput',false);  %safe for about 40 hours of recording
            handles.Spikes.HandSort.Units=...
                cellfun(@(units) int8(units), handles.Spikes.HandSort.Units,'UniformOutput',false); %256 units per channel max
            handles.Spikes.HandSort.Waveforms=...
                cellfun(@(wfs) int16(wfs), handles.Spikes.HandSort.Waveforms,'UniformOutput',false); %256 units per channel max
            handles.Spikes.HandSort.samplingRate=uint32(handles.Spikes.HandSort.samplingRate); %uint16 should be enough, but just to be on the safe side
            %squeeze in case of ND array
            squeezeIt=cellfun(@(x) numel(size(x))>2, handles.Spikes.HandSort.Waveforms,'UniformOutput',true);
            if sum(squeezeIt)
                handles.Spikes.HandSort.Waveforms=...
                    cellfun(@(x) squeeze(x), handles.Spikes.HandSort.Waveforms,'UniformOutput',false);
                handles.Spikes.HandSort.Waveforms(~squeezeIt)=...
                    cellfun(@(x) transpose(x), handles.Spikes.HandSort.Waveforms(~squeezeIt),'UniformOutput',false);
            end
            % re-order along time scale if needed
            timeOrder=cellfun(@(times) sum(diff(times)==0),...
                handles.Spikes.HandSort.SpikeTimes,'UniformOutput',true);
            if sum(timeOrder)
                [~,timeIndices]=cellfun(@(times) sort(times),...
                    handles.Spikes.HandSort.SpikeTimes,'UniformOutput',false);
                handles.Spikes.HandSort.Units=cellfun(@(units,times) units(times),...
                    handles.Spikes.HandSort.Units,timeIndices,'UniformOutput',false);
                handles.Spikes.HandSort.SpikeTimes=cellfun(@(spktimes,times) spktimes(times),...
                    handles.Spikes.HandSort.SpikeTimes,timeIndices,'UniformOutput',false);
                handles.Spikes.HandSort.Waveforms=cellfun(@(wf,times) wf(times,:),...
                    handles.Spikes.HandSort.Waveforms,timeIndices,'UniformOutput',false);
            end
            % check if empty cells
            nonEmpty=~cellfun('isempty',handles.Spikes.HandSort.Units);
            % if negative unit IDs (-1), shift all to get 0 as lowest ID
            negUnits=cellfun(@(units) sum(units<0), handles.Spikes.HandSort.Units(nonEmpty),...
                'UniformOutput',true);
            if sum(negUnits)
                handles.Spikes.HandSort.Units(nonEmpty)=...
                    cellfun(@(units) units+abs(min(units)),...
                    handles.Spikes.HandSort.Units(nonEmpty),'UniformOutput',false);
            end
            % permute dimensions if not the right orientation
            permuteIt=cellfun(@(x,y) find(size(x)==length(y))==1,...
                handles.Spikes.HandSort.Waveforms(nonEmpty),...
                handles.Spikes.HandSort.Units(nonEmpty),'UniformOutput',true);
            if sum(permuteIt)
                handles.Spikes.HandSort.Waveforms(nonEmpty)=...
                    cellfun(@(x) transpose(x), handles.Spikes.HandSort.Waveforms(nonEmpty),...
                    'UniformOutput',false);
            end
            permuteIt=cellfun(@(x) size(x,1)<numel(x), handles.Spikes.HandSort.Units(nonEmpty),...
                'UniformOutput',true);
            if sum(permuteIt)         % check units are not right as well
                handles.Spikes.HandSort.Units(nonEmpty)=...
                    cellfun(@(x) transpose(x), handles.Spikes.HandSort.Units(nonEmpty),'UniformOutput',false);
            end
            
            % downsample spike times to 1 millisecond bins
            %     spikeTimes=handles.Spikes.HandSort.SpikeTimes;
            for chNum=1:size(handles.Spikes.HandSort.samplingRate,1)
                handles.Spikes.HandSort.samplingRate(chNum,2)=1000;
                if ~isempty(handles.Spikes.HandSort.SpikeTimes{chNum,1})
                    handles.Spikes.HandSort.SpikeTimes{chNum,2}=...
                        uint32(handles.Spikes.HandSort.SpikeTimes{chNum,1})/...
                        (handles.Spikes.HandSort.samplingRate(chNum,1)/...
                        handles.Spikes.HandSort.samplingRate(chNum,2));
                else
                    handles.Spikes.HandSort.SpikeTimes{chNum,2}=[];
                end
                
                %         spikeTimeIdx=zeros(1,size(Spikes.Offline_Threshold.data{ChExN,1},2));
                %         spikeTimeIdx(Spikes.Offline_Threshold.data{ChExN,1})=1;
                %
                %         binSize=1;
                %         numBin=ceil(max(spikeTimes{chNum})/...
                %             (handles.Spikes.HandSort.samplingRate(chNum,1)/...
                %             handles.Spikes.HandSort.samplingRate(chNum,2))/binSize);
                %         % binspikeTime = histogram(double(spikeTimes), numBin); %plots directly histogram
                %         [data,binEdges] = histcounts(double(spikeTimes{chNum}),...
                %             linspace(0,max(double(spikeTimes{chNum})),numBin));
                %         data(data>1)=1; %no more than 1 spike per ms
            end
        end
    end
    %% Set number of electrodes and units,
    % if opening GUI, select electrode with most units and spikes
    if strcmp(get(handles.SelectElectrode_LB,'string'),'none')
        if diff(size(handles.rec_info.exportedChan))>0
            handles.rec_info.exportedChan=handles.rec_info.exportedChan';
        end
        set(handles.SelectElectrode_LB,'string',num2str(handles.rec_info.exportedChan));
        if isfield(handles.Spikes,'Online_Sorting') || isfield(handles.Spikes,'Offline_Sorting')
            numUnits=cellfun(@(x) sum(length(x)*unique(x)), handles.Spikes.HandSort.Units);
            electrodeNum=find(numUnits==max(numUnits),1);
            set(handles.SelectElectrode_LB,'value',electrodeNum);
        else
            set(handles.SelectElectrode_LB,'value',1)
        end
    else
        electrodeNum=get(handles.SelectElectrode_LB,'value');
    end
    
    %% color electrode by shanks
    if isfield(handles.rec_info,'probeID')
        try
            handles.userinfo=UserDirInfo;
        catch
            handles.userinfo=[];
        end
        if ~isfield(handles.userinfo,'probemap')
            if ~exist('probemaps', 'dir')
                handles.userinfo.probemap = uigetdir(cd,'select probe maps location');
                path(handles.userinfo.probemap,path)
            else
                allPathDirs=strsplit(path,pathsep);
                handles.userinfo.probemap=allPathDirs{find(cellfun(@(pathdir) contains(pathdir,'probemaps'),allPathDirs),1)};
            end
        end
        mapping=load([handles.userinfo.probemap filesep handles.rec_info.probeID '.mat']);
        differentShanks=logical(bwlabel(mod([mapping.(handles.rec_info.probeID).Shank]+1,2)));
        electrodeList= cellstr(get(handles.SelectElectrode_LB,'String'))';
        colorChannels=cell(length(electrodeList),1);
        for elNum=1:length(electrodeList) % ASSUMING ALL EXPORTED CHANNELS ARE SORTED !
            if differentShanks(elNum)>0
                colorChannels(elNum)=cellfun(@(thatChannel) sprintf(['<HTML><BODY bgcolor="%s">'...
                    '<FONT color="%s">%s</FONT></BODY></HTML>'],... %size="+1"
                    'black','white', thatChannel),electrodeList(elNum),'UniformOutput',false);
            else
                colorChannels(elNum)=cellfun(@(thatChannel) sprintf(['<HTML><BODY bgcolor="%s">'...
                    '<FONT color="%s">%s</FONT></BODY></HTML>'],... %size="+1"
                    'white','black', thatChannel),electrodeList(elNum),'UniformOutput',false);
            end
        end
        set(handles.SelectElectrode_LB, 'String', colorChannels);
    end
    
    % namestr = cellstr(get(hObject, 'String'));
    % validx = get(hObject, 'Value');
    % newstr = regexprep(namestr{validx}, '"red"','"green"');
    % namestr{validx} = newstr;
    % set(hObject, 'String', namestr);
    
    %% initialize variables
    unitsIdx=handles.Spikes.HandSort.Units{electrodeNum};
    waveForms=handles.Spikes.HandSort.Waveforms{electrodeNum};
    %     if numel(size(waveForms))>2
    %         waveForms=squeeze(waveForms);
    %     end
    
    if ~isempty(unitsIdx)
        % how many units on that electrode?
        unitsID=unique(unitsIdx); %number of clustered units
        set(handles.SelectUnit_LB,'string',num2str(unitsID));
        set(handles.SelectUnit_LB,'value',find(unitsID>0));
        
        %% take out big ouliers
        %     if find(size(waveForms)==length(unitsIdx))==1
        %         waveForms=waveForms';
        %     end
        WFmeanZ=mean(abs(zscore(single(waveForms))),2);
        % if more than one, plot it and keep
        if sum(WFmeanZ>6)>1
            figure('name', 'Artifacts','position',[30   500   500   400]);
            plot(waveForms(:,WFmeanZ>6)','linewidth',2.5); hold on;
            plot(mean(waveForms,2),'linewidth',2.5);
            legend({'Artifact','Mean waveforms'});
            title('Potential artifacts removed, mean sigma > 6');
        else
            handles.Spikes.HandSort.Units{electrodeNum}(WFmeanZ>6)=-9;%artifacts
        end
        
        % here's how this can work:
        %     Spikes detected from threshold are the benchmark (unit code = 0).
        %     May want to extract waveforms, but most important is the time.
        %     Sorted units (whatever the source) "color" those units. One spike per ms max.
        handles=Plot_Unsorted_WF(handles);
        if get(handles.ShowWF_CB,'value')
            handles=Plot_Sorted_WF(handles);
        else
            cla(handles.SortedUnits_Axes);
        end
        Plot_Mean_WF(handles);
        Plot_ISI(handles);
        Plot_ACG(handles);
        Plot_XCG(handles);
    else
        %         unitsID=[];
        set(handles.SelectUnit_LB,'string',num2str(0));
        set(handles.SelectUnit_LB,'value',1);
    end
    handles.fileLoaded=1;
end

%% Load raw traces function
function handles=LoadRawData(handles)
try
    if ~(isfield(handles,'datFile') && ~isempty(strfind(handles.datFile,'.mat')))
        handles.datFile=regexp(handles.spikeFile,'.+(?=_\w+.\w+$)','match');
        handles.datFile=[handles.datFile{:} '_raw.mat'];
        handles.datDir=cd;
    end
    handles.rawDataInfo=whos('-file',fullfile(handles.datDir,handles.datFile));
    handles.rawDataInfo=rmfield(handles.rawDataInfo,...
        {'bytes','global','sparse','complex','nesting','persistent'});
    if strfind(fullfile(handles.datDir,handles.datFile),'nopp')
        handles.rawDataInfo.preproc=0;
    else
        % if "raw" data has been pre-processed already, do
        % not process later
        handles.rawDataInfo.preproc=1;
    end
    handles.rawData = matfile(fullfile(handles.datDir,handles.datFile));
catch % try to load from .dat file
    if ~(isfield(handles,'datFile') && ~isempty(strfind(fullfile(handles.datDir,handles.datFile),'.dat')))
        if isfield(handles,'offlineSort_SpikeFile')
            handles.datFile=regexp(handles.offlineSort_SpikeFile,'.+?(?=\.)','match');
            handles.datFile=[handles.datFile{1} '.dat'];
            handles.datDir=cd;
        else
            % ask user for raw data file
        end
    end
    handles.rawData = memmapfile(fullfile(handles.datDir,handles.datFile),'Format','int16');
    handles.rawDataInfo= struct('name','rawData',...
        'size',size(handles.rawData.Data),...
        'numChan',numel(handles.rec_info.exportedChan),...
        'source','dat');
    %check in params file if data was filtered, and find threshold value
    fid  = fopen([fullfile(handles.datDir,handles.datFile(1:end-4)) '.params'],'r');
    if fid~=-1
        params=fread(fid,'*char')';
        if contains(regexp(params,'(?<=filter_done\s+=\s)\w+(?=\s)','match','once'), 'True')
            handles.rawDataInfo.preproc=1;
        else
            handles.rawDataInfo.preproc=0;
        end
        handles.rec_info.threshold=regexp(params,'(?<=spike_thresh\s+=\s)\w+(?=\s)','match','once');
        fclose(fid);
    else
        handles.rawDataInfo.preproc=0;
    end
end
handles.rawDataInfo.excerptSize=handles.rec_info.samplingRate/2; %1 second as default (-:+ around loc)
if isa(handles.rawData,'memmapfile')
    handles.rawDataInfo.excerptLocation=round(max(handles.rawDataInfo.size)/2/numel(handles.rec_info.exportedChan));  %mid-recording as default
    set(handles.TW_slider,'max',max(handles.rawDataInfo.size)/numel(handles.rec_info.exportedChan));
else
    handles.rawDataInfo.excerptLocation=round(max(handles.rawDataInfo.size)/2);
    set(handles.TW_slider,'max',max(handles.rawDataInfo.size));
end
% set(handles.TW_slider,'sliderstep',[0.01 max([0.01,...
%     handles.rawDataInfo.excerptSize/max(handles.rawDataInfo.size)])]);
% plot "raw" (filtered) trace
DisplayRawData(handles);
% plot spike rasters
DisplayRasters(handles);

%% Plot unsorted spikes
function handles=Plot_Unsorted_WF(handles)
electrodeNum=get(handles.SelectElectrode_LB,'value');
waveForms=handles.Spikes.HandSort.Waveforms{electrodeNum};
unitsIdx=handles.Spikes.HandSort.Units{electrodeNum};
samplingRate=handles.Spikes.HandSort.samplingRate(electrodeNum,1);
%% Plot unsorted spikes
numWFtoPlot=str2double(get(handles.ShowHowManyUWF_ET,'string'));
if sum(unitsIdx==0)>numWFtoPlot %then only plot subset of waveforms
    subset=find(unitsIdx==0);
    handles.subset{1}=subset(1:ceil(sum(unitsIdx==0)/numWFtoPlot):end);
else
    handles.subset{1}=find(unitsIdx==0);
end
axes(handles.UnsortedUnits_Axes); hold on;
cla(handles.UnsortedUnits_Axes);
set(handles.UnsortedUnits_Axes,'Visible','on');
if find(size(waveForms)==length(unitsIdx))==1
    waveForms=waveForms';
end
plot(waveForms(:,handles.subset{1}),'linewidth',1,'Color',[0 0 0 0.2]);
lineH=flipud(findobj(gca,'Type', 'line'));
% childH=flipud(get(gca,'Children'));
for lineTag=1:size(lineH,1)
    lineH(lineTag).Tag=num2str(handles.subset{1}(lineTag)); %Tag the unit ID
end
% foo=reshape([lineH.YData],size([lineH.YData],2)/size(lineH,1),size(lineH,1));
% faa=reshape([childH.YData],size([childH.YData],2)/size(childH,1),size(childH,1));
% lineH(80).Tag
% figure; hold on;
% plot(foo(:,80));
% plot(waveForms(:,handles.subset{1}(80)));
% [lineH.Tag]=deal(num2str(handles.subset{1}));
set(gca,'XTick',linspace(0,size(waveForms(:,handles.subset{1}),1),5),...
    'XTickLabel',round(linspace(-round(size(waveForms(:,handles.subset{1}),1)/2),...
    round(size(waveForms(:,handles.subset{1}),1)/2),5)/(double(samplingRate)/1000),2),'TickDir','out');
% ordinateLabels=str2num(get(gca,'YTickLabel'))/4;
% set(gca,'YTickLabel',num2str(ordinateLabels));
% legend('Unclustered waveforms','location','southeast')
axis('tight');box off;
xlabel('Time (ms)');
ylabelh=ylabel('Voltage (\muV)');
set(ylabelh,'interpreter','tex');
set(gca,'Color','white','FontSize',10,'FontName','Calibri');

%% Plot clusters
function handles=Plot_Sorted_WF(handles)
electrodeNum=get(handles.SelectElectrode_LB,'value');
waveForms=handles.Spikes.HandSort.Waveforms{electrodeNum};
unitsIdx=handles.Spikes.HandSort.Units{electrodeNum};
samplingRate=handles.Spikes.HandSort.samplingRate(electrodeNum,1);
% selected unit ids
axes(handles.SortedUnits_Axes); hold on;%colormap lines; cmap=colormap;
cla(handles.SortedUnits_Axes);
set(handles.SortedUnits_Axes,'Visible','on');
if get(handles.ShowAllUnits_RB,'value') %all units
    unitID=str2num(get(handles.SelectUnit_LB,'string'));
    selectedUnitsListIdx=find(unitID>0);
    selectedUnits=unitID(selectedUnitsListIdx);
else %or selected units
    unitID=str2num(get(handles.SelectUnit_LB,'string'));
    if unitID==0
        return;
    end
    selectedUnitsListIdx=get(handles.SelectUnit_LB,'value');
    if isempty(selectedUnitsListIdx) & ~isempty(unitID)
        set(handles.SelectUnit_LB,'value',1);
        selectedUnitsListIdx=1;
    end
    if sum(~ismember(unique(unitsIdx(unitsIdx>=0)),unitID))>0
        unitID=unique(unitsIdx);
    end
    if isempty(selectedUnitsListIdx) || selectedUnitsListIdx(end)>length(unitID)
        selectedUnitsListIdx=length(unitID);
    end
    selectedUnits=unitID(selectedUnitsListIdx);
    selectedUnitsListIdx=selectedUnitsListIdx(selectedUnits>0);
    selectedUnits=selectedUnits(selectedUnits>0);
end
numWFtoPlot=str2double(get(handles.ShowHowManyWF_ET,'string'));
numUnits=nan(1,length(selectedUnits));
for unitP=1:length(selectedUnits)
    numUnits(unitP)=sum(unitsIdx==selectedUnits(unitP));
    %if there are too many waveforms to plot
    if sum(unitsIdx==selectedUnits(unitP))>numWFtoPlot %then only plot subset of waveforms
        subset=find(unitsIdx==selectedUnits(unitP));
        handles.subset{selectedUnitsListIdx(unitP)}=subset(1:round(numUnits(unitP)/numWFtoPlot):end);
    else
        handles.subset{selectedUnitsListIdx(unitP)}=find(unitsIdx==selectedUnits(unitP));
    end
    %make sure waveforms can be plotted
    if find(size(waveForms)==length(unitsIdx))==1
        waveForms=waveForms';
    end
    plot(waveForms(:,handles.subset{selectedUnitsListIdx(unitP)}),...
        'linewidth',1,'Color',[handles.cmap(unitID(selectedUnitsListIdx(unitP)),:),0.4],...
        'Tag',num2str(selectedUnits(unitP)));
    %Change waveform tags from cluster number to unit ID
    lineH=flipud(findobj(gca,'Type', 'line'));
    skippedTags=0;
    if unitP==1 %define keepTags
        keepTags=cell(size(lineH,1),1);
    end
    for lineTag=1:size(lineH,1)
        % check if it's the right cluster
        if strcmp(lineH(lineTag).Tag,num2str(selectedUnits(unitP)))
            %record Tags
            keepTags{lineTag,1}=num2str(handles.subset{selectedUnitsListIdx(unitP)}(lineTag-skippedTags)); %Tag the unit ID
        else
            skippedTags=skippedTags+1;
        end
    end
    %     figure;hold on
    %     plot(lineH(lineTag).YData);
    %     plot(waveForms(:,handles.subset{selectedUnitsListIdx(unitP)}(lineTag-passedTags)))
end
%apply Tags
if exist('lineH','var')
    for lineTag=1:size(lineH,1)
        lineH(lineTag).Tag=keepTags{lineTag};
    end
    firstOfClus=[1, find(diff(cellfun(@(col) sum(col), {lineH.Color})))+1];
    legH=legend(lineH(firstOfClus),{num2str(numUnits')},'location','southeast');
    set(legH,'Box','Off','FontSize',7,'LineWidth',0.2,'Position',...
        [0.54 legH.Position(2)+legH.Position(3)-0.01 0 0]);
end
set(gca,'Ylim',[min(min(waveForms)) max(max(waveForms))],'XTick',linspace(0,size(waveForms(:,handles.subset{selectedUnitsListIdx(unitP)}),1),5),...
    'XTickLabel',round(linspace(-round(size(waveForms(:,handles.subset{selectedUnitsListIdx(unitP)}),1)/2),...
    round(size(waveForms(:,handles.subset{selectedUnitsListIdx(unitP)}),1)/2),5)/(double(samplingRate)/1000),2),...
    'TickDir','out');
axis('tight');box off;
xlabel('Time (ms)');
ylabel('Voltage (\muV)');
set(gca,'Color','white','FontSize',10,'FontName','Calibri');
hold off

%% Plot mean waveforms
function Plot_Mean_WF(handles)
electrodeNum=get(handles.SelectElectrode_LB,'value');
waveForms=handles.Spikes.HandSort.Waveforms{electrodeNum};
unitsIdx=handles.Spikes.HandSort.Units{electrodeNum};
samplingRate=handles.Spikes.HandSort.samplingRate(electrodeNum,1);
axes(handles.MeanSortedUnits_Axes); hold on;%colormap lines;
cla(handles.MeanSortedUnits_Axes);
set(handles.MeanSortedUnits_Axes,'Visible','on');
if get(handles.ShowAllUnits_RB,'value')
    unitID=str2num(get(handles.SelectUnit_LB,'string'));
    selectedUnitsListIdx=find(unitID>0);
    selectedUnits=unitID(selectedUnitsListIdx);
else
    unitID=str2num(get(handles.SelectUnit_LB,'string'));
    if unitID==0
        return;
    end
    selectedUnitsListIdx=get(handles.SelectUnit_LB,'value');
    if isempty(selectedUnitsListIdx) || selectedUnitsListIdx(end)>length(unitID)
        selectedUnitsListIdx=length(unitID);
    end
    selectedUnits=unitID(selectedUnitsListIdx);
end
numWFtoPlot=str2double(get(handles.ShowHowManyWF_ET,'string'));
for unitP=1:length(selectedUnits)
    %if subset is not defined
    if size(handles.subset,2)<selectedUnitsListIdx(unitP) || isempty(handles.subset{selectedUnitsListIdx(unitP)})
        if sum(unitsIdx==selectedUnits(unitP))>numWFtoPlot %then only plot subset of waveforms
            subset=find(unitsIdx==selectedUnits(unitP));
            handles.subset{selectedUnitsListIdx(unitP)}=subset(1:round(sum(unitsIdx==selectedUnits(unitP))/numWFtoPlot):end);
        else
            handles.subset{selectedUnitsListIdx(unitP)}=find(unitsIdx==selectedUnits(unitP));
        end
    end
    selectWF=single(waveForms(:,unitsIdx==selectedUnits(unitP))');
    if ~isnan(mean(selectWF))
        lineh(unitP)=plot(mean(selectWF),'linewidth',2,'Color',[handles.cmap(unitID(selectedUnitsListIdx(unitP)),:),0.7]);
        wfSEM=std(selectWF)/ sqrt(size(selectWF,2)); %standard error of the mean
        wfSEM = wfSEM * 1.96; % 95% of the data will fall within 1.96 standard deviations of a normal distribution
        patch([1:length(wfSEM),fliplr(1:length(wfSEM))],...
            [mean(selectWF)-wfSEM,fliplr(mean(selectWF)+wfSEM)],...
            handles.cmap(unitID(selectedUnitsListIdx(unitP)),:),'EdgeColor','none','FaceAlpha',0.2);
        %duplicate mean unit waveform over unsorted plot
        %             plot(handles.UnsortedUnits_Axes,mean(selectWF),'linewidth',2,'Color',handles.cmap(unitP,:));
        if unitP==1
            delete(findobj(handles.UnsortedUnits_Axes,'Type', 'patch'));
        end
        patch([1:length(wfSEM),fliplr(1:length(wfSEM))],...
            [mean(selectWF)-wfSEM,fliplr(mean(selectWF)+wfSEM)],...
            handles.cmap(unitID(selectedUnitsListIdx(unitP)),:),'EdgeColor','none','FaceAlpha',0.5,'Parent', handles.UnsortedUnits_Axes);
        set(handles.UnsortedUnits_Axes,'Color','white','FontSize',10,'FontName','Calibri');
    end
end
set(gca,'XTick',linspace(0,size(waveForms(:,handles.subset{selectedUnitsListIdx(unitP)}),1),5),...
    'XTickLabel',round(linspace(-round(size(waveForms(:,handles.subset{selectedUnitsListIdx(unitP)}),1)/2),...
    round(size(waveForms(:,handles.subset{selectedUnitsListIdx(unitP)}),1)/2),5)/(double(samplingRate)/1000),2),'TickDir','out');
% ordinateLabels=str2num(get(gca,'YTickLabel'))/4;
% set(gca,'YTickLabel',num2str(ordinateLabels));
if exist('selectWF','var')
    legH=legend(lineh,{num2str(selectedUnits)},'location','southeast');
    set(legH,'Box','Off');
end
axis('tight');box off;
xlabel('Time (ms)');
ylabel('Voltage (\muV)');
set(gca,'Color','white','FontSize',10,'FontName','Calibri');
hold off

%% Plot "raw" data
function dataExcerpt=DisplayRawData(handles)
electrodeNum=get(handles.SelectElectrode_LB,'value');
if isa(handles.rawData,'memmapfile')
    %set window index to correct point in data vector
    winIdxStart=(handles.rawDataInfo.excerptLocation-...
        handles.rawDataInfo.excerptSize)*numel(handles.rec_info.exportedChan);
    winIdxStart=winIdxStart-...
        mod(winIdxStart,numel(handles.rec_info.exportedChan))-... % set index loc to first electrode (should be 0 already, he)
        numel(handles.rec_info.exportedChan)+1;     % set index loc to selected electrode
    %         (numel(handles.rec_info.exportedChan) - electrodeNum);     % set index loc to selected electrode
    winIdxEnd=winIdxStart+...
        (2*handles.rawDataInfo.excerptSize*numel(handles.rec_info.exportedChan));
    excerptWindow=winIdxStart:winIdxEnd-1;
    if size(excerptWindow,2)>(2*handles.rawDataInfo.excerptSize*numel(handles.rec_info.exportedChan)) %for some reason
        excerptWindow=excerptWindow(1:end-(size(excerptWindow,2)-...
            (2*handles.rawDataInfo.excerptSize*numel(handles.rec_info.exportedChan))));
    end
    dataExcerpt=handles.rawData.Data(excerptWindow);
    dataExcerpt=reshape(dataExcerpt,[numel(handles.rec_info.exportedChan)...
        handles.rawDataInfo.excerptSize*2]);
    %         foo=handles.rawData.Data;
    %         foo=reshape(foo,[numel(handles.rec_info.exportedChan)...
    %         size(foo,1)/numel(handles.rec_info.exportedChan)]);
else
    excerptWindow=handles.rawDataInfo.excerptLocation-...
        handles.rawDataInfo.excerptSize:handles.rawDataInfo.excerptLocation+handles.rawDataInfo.excerptSize-1;
    dataExcerpt=handles.rawData.(handles.rawDataInfo.name)(:,excerptWindow);
end
if handles.rawDataInfo.preproc==0 % raw data is presumed bandpassed filtered at this point
    preprocOption={'CAR','all'};
    dataExcerpt=PreProcData(dataExcerpt,handles.rec_info.samplingRate,preprocOption);
end
dataExcerpt=int32(dataExcerpt(electrodeNum,:));
axes(handles.TimeRaster_Axes);
cla(handles.TimeRaster_Axes);
set(handles.TimeRaster_Axes,'Visible','on');
plot(handles.TimeRaster_Axes,dataExcerpt,'k','linewidth',0.1); hold on;
% threshold
if isfield(handles.rec_info,'threshold')
    threshold=str2double(handles.rec_info.threshold);
    plot(ones(1,size(dataExcerpt,2))*threshold*mad(single(dataExcerpt)),'--','Color',[0 0 0 0.3]);
    plot(ones(1,size(dataExcerpt,2))*-threshold*mad(single(dataExcerpt)),'--','Color',[0 0 0 0.3]);
else
    %     threshold=8;
end
hold off;
timeLabels=round(linspace(round(handles.rawDataInfo.excerptLocation-...
    handles.rawDataInfo.excerptSize)/(handles.rec_info.samplingRate/1000),...
    round(handles.rawDataInfo.excerptLocation+handles.rawDataInfo.excerptSize)/...
    (handles.rec_info.samplingRate/1000),4)./1000,3); % duration(X,'Format','h')
set(handles.TimeRaster_Axes,'xtick',round(linspace(0,max(get(handles.TimeRaster_Axes,'xtick')),4)),...
    'xticklabel',timeLabels); %,'TickDir','out');
set(handles.TimeRaster_Axes,'ytick',[],'yticklabel',[]); %'ylim'
axis('tight');box off;
set(handles.TimeRaster_Axes,'Color','white','FontSize',12,'FontName','calibri');
% if isa(handles.rawData,'memmapfile')
%     set(handles.TW_slider,'value',handles.rawDataInfo.excerptLocation/numel(handles.rec_info.exportedChan));
% else
set(handles.TW_slider,'value',handles.rawDataInfo.excerptLocation);

%% Plot spike unit markers
function spkTimes=DisplayRasters(handles)
% display color-coded markers for each identified spike
electrodeNum=get(handles.SelectElectrode_LB,'value');
if contains(get(handles.DisplayNtrodeMarkers_MenuItem,'Checked'),'on')
    % get channel values from same Ntrode
end
axes(handles.TimeRaster_Axes); hold on
% get which unit to plot
if get(handles.ShowAllUnits_RB,'value')
    unitID=str2num(get(handles.SelectUnit_LB,'string'));
    selectedUnitsListIdx=find(unitID>=0);
    selectedUnits=unitID(selectedUnitsListIdx);
else
    unitID=str2num(get(handles.SelectUnit_LB,'string'));
    selectedUnitsListIdx=get(handles.SelectUnit_LB,'value');
    selectedUnits=unitID(selectedUnitsListIdx);
end
spkTimes=cell(size(selectedUnits,1),1);
if isfield(handles.Spikes,'Online_Sorting') % plot above trace
    if ~isempty(handles.Spikes.Online_Sorting.SpikeTimes)
        for unitP=1:size(selectedUnits,1)
            spkTimes{unitP}=handles.Spikes.Online_Sorting.SpikeTimes{electrodeNum}(...
                (handles.Spikes.Online_Sorting.SpikeTimes{electrodeNum}>=...
                handles.rawDataInfo.excerptLocation-handles.rawDataInfo.excerptSize) &...
                (handles.Spikes.Online_Sorting.SpikeTimes{electrodeNum}<...
                handles.rawDataInfo.excerptLocation+handles.rawDataInfo.excerptSize) &...
                handles.Spikes.Online_Sorting.Units{electrodeNum}==unitID(selectedUnitsListIdx(unitP)));
            if ~isempty(spkTimes{unitP})
                rasterHeight=ones(1,size(spkTimes{unitP},2))*max(get(gca,'ylim'))/4*3;
                wfWidthComp=round(size(handles.Spikes.Online_Sorting.Waveforms{electrodeNum},1)); %will substract wf width to raster times
                plot(spkTimes{unitP}-(handles.rawDataInfo.excerptLocation-handles.rawDataInfo.excerptSize)-wfWidthComp,...
                    rasterHeight,'Color',[handles.cmap(unitID(selectedUnitsListIdx(unitP)),:),0.4],...
                    'linestyle','none','Marker','v');
            end
        end
    end
end
if isfield(handles.Spikes,'Offline_Sorting') % plot below trace
    for unitP=1:size(selectedUnits,1)
        spkTimes{unitP}=handles.Spikes.Offline_Sorting.SpikeTimes{electrodeNum}(...
            (handles.Spikes.Offline_Sorting.SpikeTimes{electrodeNum}>=...
            handles.rawDataInfo.excerptLocation-handles.rawDataInfo.excerptSize) &...
            (handles.Spikes.Offline_Sorting.SpikeTimes{electrodeNum}<...
            handles.rawDataInfo.excerptLocation+handles.rawDataInfo.excerptSize) &...
            handles.Spikes.Offline_Sorting.Units{electrodeNum}==unitID(selectedUnitsListIdx(unitP)));
        if ~isempty(spkTimes{unitP})
            rasterHeight=ones(1,size(spkTimes{unitP},2))*(min(get(gca,'ylim'))/4*3);
            if unitID(selectedUnitsListIdx(unitP))==0 %"garbage spikes"
                plot(single(spkTimes{unitP})-(handles.rawDataInfo.excerptLocation-handles.rawDataInfo.excerptSize),...
                    rasterHeight,'Color','k',...
                    'linestyle','none','Marker','*');
            else
                plot(single(spkTimes{unitP})-(handles.rawDataInfo.excerptLocation-handles.rawDataInfo.excerptSize),...
                    rasterHeight,'Color',[handles.cmap(unitID(selectedUnitsListIdx(unitP)),:),0.4],...
                    'linestyle','none','Marker','^');
            end
        end
    end
end
if get(handles.Spikes_CurrentVersion_RB,'Value') % also plot below trace, but circles
    for unitP=1:size(selectedUnits,1)
        spkTimes{unitP}=handles.Spikes.HandSort.SpikeTimes{electrodeNum}(...
            (handles.Spikes.HandSort.SpikeTimes{electrodeNum}>=...
            handles.rawDataInfo.excerptLocation-handles.rawDataInfo.excerptSize) &...
            (handles.Spikes.HandSort.SpikeTimes{electrodeNum}<...
            handles.rawDataInfo.excerptLocation+handles.rawDataInfo.excerptSize) &...
            handles.Spikes.HandSort.Units{electrodeNum}==unitID(selectedUnitsListIdx(unitP)));
        if ~isempty(spkTimes{unitP})
            rasterHeight=ones(1,size(spkTimes{unitP},2))*(min(get(gca,'ylim'))/4*3);
            if unitID(selectedUnitsListIdx(unitP))==0 %"garbage spikes"
                plot(spkTimes{unitP}-(handles.rawDataInfo.excerptLocation-handles.rawDataInfo.excerptSize),...
                    rasterHeight,'Color','k',...
                    'linestyle','none','Marker','*');
            else
                plot(spkTimes{unitP}-(handles.rawDataInfo.excerptLocation-handles.rawDataInfo.excerptSize),...
                    rasterHeight,'Color',[handles.cmap(unitID(selectedUnitsListIdx(unitP)),:),0.4],...
                    'linestyle','none','Marker','o');
            end
        end
    end
end
hold off

%% --- Executes on slider movement.
function TW_slider_Callback(hObject, ~, handles)
handles.rawDataInfo.excerptLocation=round(get(handles.TW_slider,'value'));
if handles.rawDataInfo.excerptLocation-handles.rawDataInfo.excerptSize<1
    handles.rawDataInfo.excerptLocation=handles.rawDataInfo.excerptSize+1;
elseif handles.rawDataInfo.excerptLocation+handles.rawDataInfo.excerptSize>get(handles.TW_slider,'max')
    handles.rawDataInfo.excerptLocation=get(handles.TW_slider,'max')-handles.rawDataInfo.excerptSize;
end
% plot "raw" (filtered) trace
DisplayRawData(handles);
% plot spike rasters
DisplayRasters(handles);

%% --- Executes on button press in TWplus_PB.
function TWplus_PB_Callback(hObject, ~, handles)
handles.rawDataInfo.excerptSize=handles.rawDataInfo.excerptSize*2;
mem=memory;
if ((handles.rawDataInfo.excerptSize*2+1)*2)/(0.5*mem.MemAvailableAllArrays)>1 %handles.rawDataInfo.excerptSize>
    handles.rawDataInfo.excerptSize=floor((0.5*mem.MemAvailableAllArrays)/2); % handles.rawDataInfo.size(1);
end
if handles.rawDataInfo.excerptSize*2+1>handles.rawDataInfo.size(1)
    handles.rawDataInfo.excerptSize=floor(handles.rawDataInfo.size(1)/2);
end
% plot "raw" (filtered) trace
DisplayRawData(handles);
% plot spike rasters
DisplayRasters(handles);
%  Update handles structure
guidata(hObject, handles);

%% --- Executes on button press in TWminus_PB.
function TWminus_PB_Callback(hObject, ~, handles)
handles.rawDataInfo.excerptSize=round(handles.rawDataInfo.excerptSize/2);
if handles.rawDataInfo.excerptSize<handles.rec_info.samplingRate/100
    handles.rawDataInfo.excerptSize=handles.rec_info.samplingRate/100;
end
% plot "raw" (filtered) trace
DisplayRawData(handles);
% plot spike rasters
DisplayRasters(handles);
%  Update handles structure
guidata(hObject, handles);

%% --- Executes on button press in TWall_PB.
function TWall_PB_Callback(hObject, ~, handles)
handles.rawDataInfo.excerptSize=(handles.rec_info.dur/2)-1;
mem=memory;
if ((handles.rawDataInfo.excerptSize*2+1)*2)/(0.5*mem.MemAvailableAllArrays)>1 %handles.rawDataInfo.excerptSize>
    handles.rawDataInfo.excerptSize=floor((0.5*mem.MemAvailableAllArrays)/2); % handles.rawDataInfo.size(1);
end
% plot "raw" (filtered) trace
DisplayRawData(handles);
% plot spike rasters
DisplayRasters(handles);
%  Update handles structure
guidata(hObject, handles);

%% Plot ISI
function Plot_ISI(handles)

% get which unit to plot
if get(handles.ShowAllUnits_RB,'value')
    unitID=str2num(get(handles.SelectUnit_LB,'string'));
    selectedUnitsListIdx=find(unitID>0);
    selectedUnits=unitID(selectedUnitsListIdx);
    % keep the first one
else
    unitID=str2num(get(handles.SelectUnit_LB,'string'));
    selectedUnitsListIdx=get(handles.SelectUnit_LB,'value');
    selectedUnits=unitID(selectedUnitsListIdx);
end
if isempty(selectedUnits)
    cla(handles.ISI_Axes_short);
    cla(handles.ISI_Axes_long);
    return
end
% get data values
electrodeNum=get(handles.SelectElectrode_LB,'value');
spikeTimes=handles.Spikes.HandSort.SpikeTimes{electrodeNum,1};
unitsIdx=handles.Spikes.HandSort.Units{electrodeNum};
samplingRate=handles.Spikes.HandSort.samplingRate(electrodeNum,1);

%keep the most numerous if more than one
if sum(size(selectedUnits))>1
    keepU=1;
    for uidx=1:size(selectedUnits,1)
        if sum(unitsIdx==selectedUnits(uidx))>sum(unitsIdx==selectedUnits(keepU))
            keepU=uidx;
        end
    end
    selectedUnits=selectedUnits(keepU);
end
%spike times for that unit
unitST=spikeTimes(unitsIdx==selectedUnits);
% compute interspike interval
if ~isempty(diff(unitST))
    ISI=diff(unitST)/(samplingRate/1000);
    axes(handles.ISI_Axes_short); hold on;
    cla(handles.ISI_Axes_short);
    set(handles.ISI_Axes_short,'Visible','on');
    ISIhist=histogram(double(ISI),0:max(ISI)+1);  %,'Normalization','probability'
    ISIhist.FaceColor = handles.cmap(unitID(unitID==selectedUnits),:);
    ISIhist.EdgeColor = 'k';
    xlabel('Interspike Interval (ms)')
    axis('tight');box off;
    set(gca,'xlim',[0 40],'XTick',linspace(0,40,5),'XTickLabel',linspace(0,40,5),...
        'TickDir','out','Color','white','FontSize',10,'FontName','Calibri');
    hold off
    axes(handles.ISI_Axes_long); hold on;
    cla(handles.ISI_Axes_long);
    set(handles.ISI_Axes_long,'Visible','on');
    ISIhist=histogram(double(ISI),0:5:max(ISI)+1);  %,'Normalization','probability'
    ISIhist.FaceColor = handles.cmap(unitID(unitID==selectedUnits),:);
    ISIhist.EdgeColor = 'k';
    xlabel('Interspike Interval (ms)')
    axis('tight');box off;
    set(gca,'xlim',[0 700],'XTick',linspace(0,700,5),'XTickLabel',linspace(0,700,5),...
        'TickDir','out','Color','white','FontSize',10,'FontName','Calibri');
    hold off
end

%% Plot autocorrelogram
function Plot_ACG(handles)
% get which unit to plot
if get(handles.ShowAllUnits_RB,'value')
    unitID=str2num(get(handles.SelectUnit_LB,'string'));
    selectedUnitsListIdx=find(unitID>0);
    selectedUnits=unitID(selectedUnitsListIdx);
    % keep the first one
else
    unitID=str2num(get(handles.SelectUnit_LB,'string'));
    selectedUnitsListIdx=get(handles.SelectUnit_LB,'value');
    selectedUnits=unitID(selectedUnitsListIdx);
end
if isempty(selectedUnits)
    cla(handles.ACG_Axes);
    return
end

electrodeNum=get(handles.SelectElectrode_LB,'value');
spikeTimes=handles.Spikes.HandSort.SpikeTimes{electrodeNum,1};
unitsIdx=handles.Spikes.HandSort.Units{electrodeNum};
samplingRate=handles.Spikes.HandSort.samplingRate(electrodeNum,1);

%keep the most numerous if more than one
if sum(size(selectedUnits))>1
    keepU=1;
    for uidx=1:size(selectedUnits,1)
        if sum(unitsIdx==selectedUnits(uidx))>sum(unitsIdx==selectedUnits(keepU))
            keepU=uidx;
        end
    end
    selectedUnits=selectedUnits(keepU);
end
%get unit spike times
unitST=spikeTimes(unitsIdx==selectedUnits);
% change to ms timescale
unitST=unitST/(samplingRate/1000);
%get ISI
% ISI=diff(unitST)/(samplingRate/1000);
%bin
spikeTimeIdx=zeros(1,unitST(end));
spikeTimeIdx(unitST)=1;
binSize=5;
numBin=ceil(size(spikeTimeIdx,2)/binSize);
binUnits = histcounts(double(unitST), linspace(0,size(spikeTimeIdx,2),numBin));
binUnits(binUnits>1)=1; %no more than 1 spike per ms
% compute autocorrelogram
[ACG,lags]=xcorr(double(binUnits),200,'unbiased'); %'coeff'
ACG(lags==0)=0;
axes(handles.ACG_Axes); hold on;
cla(handles.ACG_Axes);
set(handles.ACG_Axes,'Visible','on');
ACGh=bar(lags,ACG);
ACGh.FaceColor = handles.cmap(unitID(unitID==selectedUnits),:);
ACGh.EdgeColor = 'none';
axis('tight');box off;
xlabel('Autocorrelogram (5 ms bins)')
set(gca,'xlim',[-50 50],'Color','white','FontSize',10,'FontName','Calibri','TickDir','out');
hold off

%% Plot cross-correlogram
function Plot_XCG(handles)
% get which unit to plot
if get(handles.ShowAllUnits_RB,'value')
    cla(handles.XCorr_Axes);
    return
else
    unitID=str2num(get(handles.SelectUnit_LB,'string'));
    selectedUnitsListIdx=get(handles.SelectUnit_LB,'value');
    selectedUnits=unitID(selectedUnitsListIdx);
end
if isempty(selectedUnits)
    cla(handles.XCorr_Axes);
    return
end

electrodeNum=get(handles.SelectElectrode_LB,'value');
spikeTimes=handles.Spikes.HandSort.SpikeTimes{electrodeNum,1};
unitsIdx=handles.Spikes.HandSort.Units{electrodeNum};
samplingRate=handles.Spikes.HandSort.samplingRate(electrodeNum,1);

%keep the most numerous if more than one
if length(selectedUnits)~=2
    cla(handles.XCorr_Axes);
    return
end
%get units spike times
unitST{1}=spikeTimes(unitsIdx==selectedUnits(1));
unitST{2}=spikeTimes(unitsIdx==selectedUnits(2));
% change to ms timescale
unitST{1}=unitST{1}/(samplingRate/1000);
unitST{2}=unitST{2}/(samplingRate/1000);

%bin
spikeTimeIdx{1}=zeros(1,unitST{1}(end));
spikeTimeIdx{1}(unitST{1})=1;
spikeTimeIdx{2}=zeros(1,unitST{2}(end));
spikeTimeIdx{2}(unitST{2})=1;
binSize=5;
numBin=max(ceil(size(spikeTimeIdx{1},2)/binSize),ceil(size(spikeTimeIdx{2},2)/binSize));
binUnits{1} = histcounts(double(unitST{1}), linspace(0,size(spikeTimeIdx{1},2),numBin));
binUnits{1}(binUnits{1}>1)=1; %no more than 1 spike per ms
binUnits{2} = histcounts(double(unitST{2}), linspace(0,size(spikeTimeIdx{2},2),numBin));
binUnits{2}(binUnits{2}>1)=1; %no more than 1 spike per ms

% compute autocorrelogram
[XCG,lags]=xcorr(double(binUnits{1}),double(binUnits{2}),200,'unbiased'); %'coeff'
XCG(lags==0)=0;
axes(handles.XCorr_Axes); hold on;
cla(handles.XCorr_Axes);
set(handles.XCorr_Axes,'Visible','on');
XCGh=bar(lags,XCG);
XCGh.FaceColor = (handles.cmap(unitID(unitID==selectedUnits(1)),:)+...
    handles.cmap(unitID(unitID==selectedUnits(2)),:))/2;
XCGh.EdgeColor = 'none';
axis('tight');box off;
xlabel('CrossCorrelogram (5 ms bins)')
set(gca,'xlim',[-50 50],'Color','white','FontSize',10,'FontName','Calibri','TickDir','out');
hold off

% function  Plot_Raster_TW(handles)
% %% plot rasters
% electrodeNum=get(handles.SelectElectrode_LB,'value');
% spikeTimes=handles.Spikes.HandSort.SpikeTimes{electrodeNum,2};

% plot 10 sec or numWFtoPlot waveforms max

%% --- Executes on mouse press over unsorted units axes
function UnsortedUnits_Axes_ButtonDownFcn(hObject, ~, handles)
% left click to start selection line
% right click to end it

electrodeNum=get(handles.SelectElectrode_LB,'value');

%% initialize variables
unitsIdx=find(handles.Spikes.HandSort.Units{electrodeNum}==0);
% waveForms=handles.Spikes.HandSort.Waveforms{electrodeNum};
% spikeTimes=handles.Spikes.HandSort.SpikeTimes{electrodeNum,2};
% samplingRate=handles.Spikes.HandSort.samplingRate(electrodeNum,1);

lineH=findobj(gca,'Type', 'line');

%adjust number of waveforms to those displayed.
% or pull it from handles
visibleLines=cellfun(@(x) strcmp(x,'on'), {lineH.Visible});

waveForms=fliplr(reshape([lineH(visibleLines).YData],...
    size([lineH(visibleLines).YData],2)/size(lineH(visibleLines),...
    1),size(lineH(visibleLines),1)));
waveForms=waveForms';%one waveform per row

% foo=fliplr(reshape([lineH(~visibleLines).YData],...
%     size([lineH(~visibleLines).YData],2)/size(lineH(~visibleLines),...
%     1),size(lineH(~visibleLines),1)));
% figure;hold on;plot(foo,'k');

%This is the unsorted units plot
% make cluster classes 0 (unsorted), and -1 (hidden)
% clusterClasses=ones(size(waveForms,2),1)*-1;
% clusterClasses(handles.subset{1})=0;%mark subset visible (might be all of them)
% clusterClasses=clusterClasses(unitsIdx==0);%remove those already sorted
clusterClasses=zeros(size(waveForms,1),1);

%some other plots may have been overlayed. All unsorted lines should be black
if sum(cellfun(@(x) sum(x), {lineH.Color})~=0)
    %     %add waveform data to waveforms matrix
    %     waveForms=[reshape([lineH(cellfun(@(x) sum(x), {lineH.Color})~=0).YData],...
    %         size(waveForms,1),sum(cellfun(@(x) sum(x), {lineH.Color})~=0)),waveForms];
    %     clusterClasses=[ones(sum(cellfun(@(x) sum(x), {lineH.Color})~=0),1)*-10;...
    %         clusterClasses];
    
    % change ClusterClass to -10
end

clusterClasses=InteractiveClassification(waveForms,clusterClasses,0); % viewClasses=0
% find similar waveforms that were not plotted
% if numel(find(handles.Spikes.HandSort.Units{electrodeNum}==0))>numel(clusterClasses) &...
%         sum(logical(clusterClasses))
%     meanSelectedWF=mean(handles.Spikes.HandSort.Waveforms{electrodeNum}(:,...
%         unitsIdx(logical(clusterClasses))),2);
%     allWF=handles.Spikes.HandSort.Waveforms{electrodeNum}(:,unitsIdx);
%     for wfNum=1:size(allWF,2)
%         ccVal(wfNum)=median(xcorr(double(allWF(:,wfNum)'),...
%             double(meanSelectedWF')),2);
%     end
%     figure;
%     plot(allWF(:,unitsIdx(logical(clusterClasses)))')
% end

handles.Spikes.HandSort.Units{electrodeNum}(unitsIdx(logical(clusterClasses)))=...
    clusterClasses(logical(clusterClasses));
unitsID=unique(handles.Spikes.HandSort.Units{electrodeNum});
%Check if unit selection still works
unitSelection=get(handles.SelectUnit_LB,'Value');
try
    unitsID(get(handles.SelectUnit_LB,'Value'));
catch
    unitSelection=unitSelection(ismember(unitSelection,(1:numel(unitsID))));
end
unitSelection(unitsID(unitSelection)==0)=unitSelection(unitsID(unitSelection)==0)+1;
set(handles.SelectUnit_LB,'Value',unitSelection);
set(handles.SelectUnit_LB,'String',num2str(unitsID(unitsID>=0)));
if max(get(handles.SelectUnit_LB,'value'))>length(str2num(get(handles.SelectUnit_LB,'string')))
    newSelection=get(handles.SelectUnit_LB,'value')-...
        (max(get(handles.SelectUnit_LB,'value'))-length(str2num(get(handles.SelectUnit_LB,'string'))));
    newSelection=newSelection(newSelection>0);
    set(handles.SelectUnit_LB,'value',newSelection);
end
if find(clusterClasses>0,1)
    if get(handles.ShowWF_CB,'value')
        handles=Plot_Sorted_WF(handles);
    else
        cla(handles.SortedUnits_Axes);
    end
    Plot_Mean_WF(handles);
    Plot_ISI(handles);
    Plot_ACG(handles);
    Plot_XCG(handles);
end
%  Update handles structure
guidata(hObject, handles);

%% --- Executes on mouse press over sorted units axes
function SortedUnits_Axes_ButtonDownFcn(hObject, ~, handles)
electrodeNum=get(handles.SelectElectrode_LB,'value');

%% initialize variables
unitID=str2num(get(handles.SelectUnit_LB,'string'));
% for uIdxNum=1:length(unitsID)
%     unitsIdx{uIdxNum}=find(handles.Spikes.HandSort.Units{electrodeNum}==unitsID(uIdxNum));
% end
unitsIdx=handles.Spikes.HandSort.Units{electrodeNum};

lineH=findobj(gca,'Type', 'line');
visibleLines=cellfun(@(x) strcmp(x,'on'), {lineH.Visible});

waveForms=fliplr(reshape([lineH(visibleLines).YData],...
    size([lineH(visibleLines).YData],2)/size(lineH(visibleLines),...
    1),size(lineH(visibleLines),1)));
waveForms=waveForms';%one waveform per row

linesTags=flip(cellfun(@(x) str2double(x), {lineH(visibleLines).Tag}));
% ismember(find(unitsIdx==2),linesClasses)
clusterClasses=unitsIdx(linesTags)';
% figure;hold on
% plot(waveForms(530:537,:)','r')
% plot(waveForms(1:8,:)','b')
if get(handles.ShowAllUnits_RB,'value')
    selectedUnitsListIdx=find(unitID>0);
    viewClasses=unitID(selectedUnitsListIdx);
else
    selectedUnitsListIdx=get(handles.SelectUnit_LB,'value');
    viewClasses=unitID(selectedUnitsListIdx);
end

[clusterClasses,lineSelecIdx]=InteractiveClassification(waveForms,clusterClasses,viewClasses); % viewClasses=0
% foo=handles.Spikes.HandSort.Waveforms{electrodeNum}; foo=foo';
% figure;plot(foo(unitsIdx(logical(clusterClasses)),:)');hold on
% plot(lineH(flip(logical(clusterClasses))).YData)
%
% waveForms=handles.Spikes.HandSort.Waveforms{electrodeNum};
% figure; plot(waveForms(:,linesTags(lineSelecIdx)))
if lineSelecIdx==0
    return
else
    set(handles.Spikes_OriginalVersion_RB,'Value',0);
    set(handles.Spikes_CurrentVersion_RB,'Value',1);
end
handles.Spikes.HandSort.Units{electrodeNum}(linesTags(lineSelecIdx))=...
    clusterClasses(lineSelecIdx);
unitsID=unique(handles.Spikes.HandSort.Units{electrodeNum});
%Check if unit selection still works
unitSelection=get(handles.SelectUnit_LB,'Value');
try
    unitsID(get(handles.SelectUnit_LB,'Value'));
catch
    unitSelection=unitSelection(ismember(unitSelection,(1:numel(unitsID))));
end
unitSelection(unitsID(unitSelection)==0)=unitSelection(unitsID(unitSelection)==0)+1;
set(handles.SelectUnit_LB,'Value',unitSelection);
set(handles.SelectUnit_LB,'String',num2str(unitsID(unitsID>=0)))
if find(clusterClasses>0,1)
    if get(handles.ShowWF_CB,'value')
        handles=Plot_Sorted_WF(handles);
    else
        cla(handles.SortedUnits_Axes);
    end
end
if find(clusterClasses==0,1)
    handles=Plot_Unsorted_WF(handles);
end
Plot_Mean_WF(handles);
Plot_ISI(handles);
Plot_ACG(handles);
Plot_XCG(handles);
%  Update handles structure
guidata(hObject, handles);

%% --- Executes on mouse press over mean sorted units axes.
function MeanSortedUnits_Axes_ButtonDownFcn(hObject, ~, handles)
unitID=str2num(get(handles.SelectUnit_LB,'string'));
electrodeNum=get(handles.SelectElectrode_LB,'value');

%% initialize variables
unitsIdx=handles.Spikes.HandSort.Units{electrodeNum};

lineH=findobj(gca,'Type', 'line');
visibleLines=cellfun(@(x) strcmp(x,'on'), {lineH.Visible});

waveForms=fliplr(reshape([lineH(visibleLines).YData],...
    size([lineH(visibleLines).YData],2)/size(lineH(visibleLines),...
    1),size(lineH(visibleLines),1)));
waveForms=waveForms';%one waveform per row

[clusterClasses,viewClasses]=deal(flip(cellfun(@(x) str2double(x), {lineH(visibleLines).DisplayName})));
% figure;hold on
% plot(waveForms(1,:)','r')
% plot(waveForms(3,:)','b')

[newClasses,lineSelecIdx,groupReclass]=InteractiveClassification(waveForms,clusterClasses,viewClasses); % viewClasses=0
% foo=handles.Spikes.HandSort.Waveforms{electrodeNum}; foo=foo';
% figure;plot(foo(unitsIdx(logical(clusterClasses)),:)');hold on
% plot(lineH(flip(logical(clusterClasses))).YData)
%
% waveForms=handles.Spikes.HandSort.Waveforms{electrodeNum};
% figure; plot(waveForms(:,linesTags(lineSelecIdx)))

if lineSelecIdx==0
    return
else
    set(handles.Spikes_OriginalVersion_RB,'Value',0);
    set(handles.Spikes_CurrentVersion_RB,'Value',1);
end

changeUnits=clusterClasses(clusterClasses~=unique(newClasses(lineSelecIdx)) & lineSelecIdx');
for chgu=1:length(changeUnits)
    handles.Spikes.HandSort.Units{electrodeNum}(unitsIdx==changeUnits(chgu))=...
        unique(newClasses(lineSelecIdx));
end

if groupReclass==1 && sum(lineSelecIdx)==1
    
    selectedWF=double(waveForms(lineSelecIdx,:));
    WFpeak=find(abs(selectedWF)==max(abs(selectedWF)),1);
    wfRange=WFpeak-9:WFpeak+8;
    selectedWF=selectedWF(wfRange);
    allWf=handles.Spikes.HandSort.Waveforms{electrodeNum}; allWf=double(allWf(wfRange,:)');
    
    % figure; hold on
    % plot(selectedWF);
    allWf_wRef=[selectedWF;allWf];
    minDif=allWf_wRef-repmat(selectedWF,size(allWf_wRef,1),1);
    % figure; hist(median(abs(minDif')),20)
    % minResidual=find(median(abs(minDif'))==min(median(abs(minDif'))),1);
    maxPeaks=zscore(allWf_wRef')'.*repmat(selectedWF,size(allWf_wRef,1),1);
    % maxMultiplied=find(max(abs(maxPeaks'))==max(max(abs(maxPeaks'))),1);
    % plot(allWf_wRef(minResidual,:))
    % plot(allWf_wRef(maxMultiplied,:))
    
    roughCat=([median(abs(minDif'))' max(abs(maxPeaks'))']);
    [~,PrComps] = pca(roughCat);
    % figure
    % scatter(PrComps(:,1), PrComps(:,2), 'k.');
    clusterCat = gmdistribution(PrComps(1,:),...
        [abs(min(PrComps(:,1)))+abs(max(PrComps(:,1))),...
        -0; -0, abs(min(PrComps(:,2)))+abs(max(PrComps(:,2)))]);
    mahalDis = mahal(clusterCat,PrComps(2:end,:));
    % scatter(PrComps(:,1),PrComps(:,2),50,mahalDis(:,1),'.')
    % hb = colorbar;
    % ylabel(hb,'Mahalanobis Distance to Component 1')
    
    similIdx=find(mahalDis<max(mahalDis)/10);
    % figure
    % scatter(PrComps(similIdx,1), PrComps(similIdx,2), 'k.');
    
    subsetWF=allWf(similIdx,:);
    [cc, ccv]=deal(nan(size(subsetWF,1),1));
    for wf=1:size(subsetWF,1)
        cc(wf)=max(abs(xcorr((selectedWF),(subsetWF(wf,:)),2,'coeff'))); %'unbiased' 'coeff'
    end
    
    for wf=1:size(subsetWF,1)
        ccv(wf)=max(abs(xcov((selectedWF),(subsetWF(wf,:)),2,'biased'))); %'unbiased' 'coeff'
    end
    
    %     clustev = evalclusters([cc ccv], 'kmeans', 'silhouette', 'KList',
    %     2:3); this takes too long, do not use clustev.OptimalK
    [clusIdx ,Centroids]= kmeans([cc ccv],2,'Distance','cityblock',...
        'Replicates',5);
    
    % figure; hold on
    % plot(mean(subsetWF(clusIdx==2,:)))
    
    similWF=similIdx(clusIdx==find(Centroids(:,2)==max(Centroids(:,2))));
    % figure; plot(mean(allWf(similWF,:)))
    
    handles.Spikes.HandSort.Units{electrodeNum}(similWF)=...
        unique(newClasses(lineSelecIdx));
end

unitsID=unique(handles.Spikes.HandSort.Units{electrodeNum});
%Check if unit selection still works
unitSelection=get(handles.SelectUnit_LB,'Value');
if get(handles.ShowAllUnits_RB,'value')
    unitSelection=find(unitsID>0);
else
    unitSelection=unitSelection(ismember(unitSelection,(1:numel(unitsID))));
end
unitSelection(unitsID(unitSelection)==0)=unitSelection(unitsID(unitSelection)==0)+1;
set(handles.SelectUnit_LB,'Value',unitSelection);
set(handles.SelectUnit_LB,'String',num2str(unitsID(unitsID>=0)))
if find(clusterClasses>0,1)
    if get(handles.ShowWF_CB,'value')
        handles=Plot_Sorted_WF(handles);
    else
        cla(handles.SortedUnits_Axes);
    end
end
if find(clusterClasses==0,1)
    handles=Plot_Unsorted_WF(handles);
end
Plot_Mean_WF(handles);
Plot_ISI(handles);
Plot_ACG(handles);
Plot_XCG(handles);
%  Update handles structure
guidata(hObject, handles);

%% --- Executes on selection change in SelectElectrode_LB.
function SelectElectrode_LB_Callback(hObject, ~, handles)
if strcmp(get(gcf,'SelectionType'),'normal')
    handles=LoadSpikes(handles);
    % plot "raw" (filtered) trace
    DisplayRawData(handles);
    % plot spike rasters
    DisplayRasters(handles);
    % Update handles structure
    guidata(hObject, handles);
end

%% Get channel and unit selection
%     channelMenu=get(handles.SelectElectrode_LB,'string');
%     channelSelected=get(handles.SelectElectrode_LB,'value');
%     channelSelected=channelMenu(channelSelected);
%
%     unitMenu=get(handles.SelectUnit_LB,'string');
%     unitsSelected=get(handles.SelectUnit_LB,'value');
%     unitsSelected=unitMenu(unitsSelected);

%% --- Executes on selection change in SelectUnit_LB.
function SelectUnit_LB_Callback(hObject, ~, handles)
set(handles.ShowAllUnits_RB,'value',0)
if strcmp(get(gcf,'SelectionType'),'normal')
    %     = cellstr(get(hObject,'String'))
    %        contents{get(hObject,'Value')}
    if get(handles.ShowWF_CB,'value')
        handles=Plot_Sorted_WF(handles);
    else
        cla(handles.SortedUnits_Axes);
    end
    Plot_Mean_WF(handles);
    Plot_ISI(handles);
    Plot_ACG(handles);
    Plot_XCG(handles);
    DisplayRawData(handles);
    DisplayRasters(handles);
    
    % elseif strcmp(get(gcf,'SelectionType'),'open') % double click
    % else
    %  Update handles structure
    guidata(hObject, handles);
end

%% --- Executes on button press in ShowAllUnits_RB.
function ShowAllUnits_RB_Callback(hObject, ~, handles)
if get(hObject,'Value')
    if get(handles.ShowWF_CB,'value')
        handles=Plot_Sorted_WF(handles);
    else
        cla(handles.SortedUnits_Axes);
    end
    Plot_Mean_WF(handles);
    Plot_ISI(handles);
    Plot_ACG(handles);
    Plot_XCG(handles);
    guidata(hObject, handles);
end

%% --- Executes on button press in PreviewTh_PB.
function PreviewTh_PB_Callback(hObject, ~, handles)
if ~isfield(handles,'datFile')
    handles.datFile=[cell2mat(regexp(handles.spikeFile,'.+(?=\_\w+\_\w+\.)','match')) '_nopp'];
end
handles.PreviewTh_PB.ForegroundColor=[0.2 0.5 0.7];
RunSpykingCircus(cd,handles.datFile,{'previewspkc'});
handles.PreviewTh_PB.ForegroundColor=[0.3490 0.2000 0.3294];

%% --- Executes on button press in LauncherGUI_PB.
function LauncherGUI_PB_Callback(hObject, eventdata, handles)
if ~isfield(handles,'datFile')
    handles.datFile=[cell2mat(regexp(handles.spikeFile,'.+(?=\_\w+\_\w+\.)','match')) '_nopp'];
end
RunSpykingCircus(cd,handles.datFile,{'launcherGUI'});

%% --- Executes on button press in RefineSort_PB.
function RefineSort_PB_Callback(hObject, ~, handles)
if ~isfield(handles,'datFile')
    handles.datFile=[cell2mat(regexp(handles.spikeFile,'.+(?=\_\w+\_\w+\.)','match')) '_nopp'];
end
handles.RefineSort_PB.ForegroundColor=[0.2 0.5 0.7];
[status,cmdout]=RunSpykingCircus(cd,handles.datFile,{'startVisGUI'});
handles.RefineSort_PB.ForegroundColor=[0.3490 0.2000 0.3294];

%% --- Outputs from this function are returned to the command line.
function varargout = SpikeVisualizationGUI_OutputFcn(hObject, ~, handles)

% Get default command line output from handles structure
varargout{1} = handles.output;

%% --- Executes on button press in Spikes_SortOn_RB.
function Spikes_SortOn_RB_Callback(hObject, ~, handles)
set(handles.Spikes_SortOn_RB,'value',1);
set(handles.Spikes_SortOff_RB,'value',0);
set(handles.Spikes_Th_RB,'value',0);
% [handles.spikeFile,handles.exportDir] = uigetfile({'*.mat;*.hdf5','All Data Formats';...
%     '*.*','All Files' },'Export folder',handles.exportDir);
handles.fileLoaded=0;
handles=LoadSpikes(handles);
% Update handles structure
guidata(hObject, handles);

%% --- Executes on button press in Spikes_SortOff_RB.
function Spikes_SortOff_RB_Callback(hObject, ~, handles)
set(handles.Spikes_SortOff_RB,'value',1);
set(handles.Spikes_SortOn_RB,'value',0);
set(handles.Spikes_Th_RB,'value',0);

[handles.spikeFile,handles.exportDir] = uigetfile({'*.mat;*.hdf5','All Data Formats';...
    '*.*','All Files' },'Export folder',handles.exportDir);
handles.fileLoaded=0;
handles=LoadSpikes(handles);
% plot "raw" (filtered) trace
DisplayRawData(handles);
% plot spike rasters
DisplayRasters(handles);
% Update handles structure
guidata(hObject, handles);

%% --- Executes on button press in Spikes_Th_RB.
function Spikes_Th_RB_Callback(hObject, ~, handles)
set(handles.Spikes_Th_RB,'value',1);
set(handles.Spikes_SortOn_RB,'value',0);
set(handles.Spikes_SortOff_RB,'value',0);
if isempty(handles.spikeFile) || ~strcmp(handles.spikeFile(end-2:end),'mat')
    [handles.spikeFile,handles.exportDir] = uigetfile({'*.mat;*.hdf5','All Data Formats';...
        '*.*','All Files' },'Export folder',handles.exportDir);
end
handles.fileLoaded=0;
handles=LoadSpikes(handles);
% Update handles structure
guidata(hObject, handles);

% --- Executes on button press in Spikes_PrevSorted_RB.
function Spikes_PrevSorted_RB_Callback(hObject, eventdata, handles)
set(handles.Spikes_PrevSorted_RB,'value',1);
set(handles.Spikes_Th_RB,'value',0);
set(handles.Spikes_SortOn_RB,'value',0);
set(handles.Spikes_SortOff_RB,'value',0);
if ~strcmp(handles.spikeFile(end-2:end),'mat')
    [handles.spikeFile,handles.exportDir] = uigetfile({'*.mat;*.hdf5','All Data Formats';...
        '*.*','All Files' },'Export folder',handles.exportDir);
end
handles.fileLoaded=0;
handles=LoadSpikes(handles);
% Update handles structure
guidata(hObject, handles);

% --- Executes on button press in PeakReAlign_PB.
function PeakReAlign_PB_Callback(hObject, eventdata, handles)
% confirm re-alignment
confirm = questdlg('Realign Spikes Waveforms?', ...
    'Spike Alignment','Yes','No thank you','Yes');
switch confirm
    case 'Yes'
        % first load raw traces
        %         tb_filename=regexp(handles.spikeFile,'.+(?=_\w+.\w+$)','match');
        %         load([tb_filename{:} '_raw.mat']);
        selectedEl=get(handles.SelectElectrode_LB,'value');
        rawData=handles.rawData.(handles.rawDataInfo.name)(selectedEl,:);
        %then re-align (current waveforms, raw data, spike times, unit IDs)
        Spikes=ReAlignSpikes(handles.Spikes.HandSort.Waveforms{selectedEl,1},...
            rawData,...
            handles.Spikes.HandSort.SpikeTimes{selectedEl,1},...
            handles.Spikes.HandSort.Units{selectedEl,1});
        handles.Spikes.HandSort.Waveforms(selectedEl)=Spikes.Waveforms;
        handles.Spikes.HandSort.Waveforms(selectedEl)=...
            cellfun(@(wfs) int16(wfs), handles.Spikes.HandSort.Waveforms{selectedEl},'UniformOutput',false); %256 units per channel max
        handles.Spikes.HandSort.SpikeTimes(selectedEl,1)=Spikes.SpikeTimes;
        % downsample spike times to 1 millisecond bins
        for ElNum=1:length(selectedEl)
            if ~isempty(handles.Spikes.HandSort.SpikeTimes{ElNum,1})
                handles.Spikes.HandSort.SpikeTimes{ElNum,2}=...
                    uint32(handles.Spikes.HandSort.SpikeTimes{ElNum,1})/...
                    (handles.Spikes.HandSort.samplingRate(ElNum,1)/...
                    handles.Spikes.HandSort.samplingRate(ElNum,2));
            else
                handles.Spikes.HandSort.SpikeTimes{ElNum,2}=[];
            end
        end
    case 'No thank you'
        %OK
end
handles=Plot_Unsorted_WF(handles);
if get(handles.ShowWF_CB,'value')
    handles=Plot_Sorted_WF(handles);
else
    cla(handles.SortedUnits_Axes);
end
Plot_Mean_WF(handles);
% Update handles structure
guidata(hObject, handles);

%% --- Executes during object creation, after setting all properties.
function SelectElectrode_LB_CreateFcn(hObject, ~, handles)

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%% --- Executes during object creation, after setting all properties.
function SelectUnit_LB_CreateFcn(hObject, ~, handles)

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%% --- Executes during object creation, after setting all properties.
function TW_slider_CreateFcn(hObject, ~, handles)

if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.839 .91 .851]);
end

%% --- Executes on button press in LoadFile_PB.
function LoadFile_PB_Callback(hObject, ~, handles)
if isfield(handles,'spikeFile')
    handles = rmfield(handles,'spikeFile');
end
userinfo=UserDirInfo;
%% get most recently changed data folder
exportDir=regexprep(userinfo.directory,'\\\w+$','\\export');
dataDirListing=dir(exportDir);
%removing dots
dataDirListing=dataDirListing(cellfun('isempty',cellfun(@(x) strfind(x,'.'),...
    {dataDirListing.name},'UniformOutput',false)));
%removing other folders
dataDirListing=dataDirListing(cellfun('isempty',cellfun(@(x)...
    regexp('list | all | unwanted | folders | here ',x),...
    {dataDirListing.name},'UniformOutput',false)));
[~,fDateIdx]=sort([dataDirListing.datenum],'descend');
recentDataFolder=[exportDir filesep dataDirListing(fDateIdx(1)).name filesep];

% open user input window
[handles.spikeFile,handles.exportDir] = uigetfile({'*.mat;*.hdf5','Export Formats';...
    '*.dat','Raw data';'*.*','All Files' },'Most recent data',recentDataFolder);
if handles.spikeFile==0
    handles.spikeFile='';
    handles.exportDir=recentDataFolder;
else
    handles.fileLoaded=0;
    handles=LoadSpikes(handles);
end

% Update handles structure
guidata(hObject, handles);

%% --- Executes on button press in Reload_PB.
function Reload_PB_Callback(hObject, ~, handles)

%% --- Executes on button press in Save_PB.
function Save_PB_Callback(hObject, ~, handles)
%     userinfo=UserDirInfo;
%     save([handles.exportDir filesep cell2mat(regexp(handles.fname,'.+(?=\.)','match'))...
%         '_spikesResorted'],'-struct','handles','Spikes','-v7.3');
try
    save([handles.exportDir  cell2mat(regexp(handles.spikeFile,'.+(?=_spikes)','match'))...
        '_spikesResorted'],'-struct','handles','spikeFile','exportDir','datFile','datDir',...
        'Spikes','rec_info','subset','-v7.3');
catch
    if isfield(handles,'offlineSort_SpikeFile') && ~isempty(handles.offlineSort_SpikeFile)
        %     handles.offlineSort_SpikeDir=handles.exportDir;
        %             handles.offlineSort_SpikeFile=handles.spikeFile;
        %             %go one folder up
        %             exportDirUp=handles.exportDir(1:regexp(handles.exportDir,'\\\w+\\$'));
        exportDirListing=dir(handles.datDir);
        infoFile=exportDirListing(~cellfun('isempty',cellfun(@(x) strfind(x,'_info.'),...
            {exportDirListing.name},'UniformOutput',false))).name;
        save([handles.datDir  cell2mat(regexp(infoFile,'.+(?=_info)','match'))...
            '_spikesResorted'],'-struct','handles','spikeFile','exportDir',...
            'Spikes','rec_info','subset','-v7.3');
    else
        save([handles.exportDir  handles.datFile(1:end-4)  ...
            '_spikesResorted.mat'],'-struct','handles','spikeFile','exportDir',...
            'Spikes','rec_info','subset','-v7.3');
    end
end


% --- Executes on button press in ShowWF_CB.
function ShowWF_CB_Callback(hObject, eventdata, handles)

function ShowUWF_CB_Callback(hObject, eventdata, handles)

function ShowHowManyUWF_ET_Callback(hObject, eventdata, handles)

function ShowHowManyUWF_ET_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in Spikes_CurrentVersion_RB.
function Spikes_CurrentVersion_RB_Callback(hObject, eventdata, handles)
% hObject    handle to Spikes_CurrentVersion_RB (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% --- Executes on button press in Spikes_OriginalVersion_RB.
function Spikes_OriginalVersion_RB_Callback(hObject, eventdata, handles)
% hObject    handle to Spikes_OriginalVersion_RB (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% --- Executes on button press in ExportData_PB.
function ExportData_PB_Callback(hObject, eventdata, handles)
electrodeNum=get(handles.SelectElectrode_LB,'value');
waveForms=handles.Spikes.HandSort.Waveforms{electrodeNum};
spikeTimes=handles.Spikes.HandSort.SpikeTimes{electrodeNum,:};
unitsIdx=handles.Spikes.HandSort.Units{electrodeNum};
samplingRate=handles.Spikes.HandSort.samplingRate(electrodeNum,1);

if get(handles.ShowAllUnits_RB,'value')
    unitID=str2num(get(handles.SelectUnit_LB,'string'));
    selectedUnits=unitID(unitID>0);
else
    unitID=str2num(get(handles.SelectUnit_LB,'string'));
    if unitID==0
        return;
    end
    selectedUnitsListIdx=get(handles.SelectUnit_LB,'value');
    if isempty(selectedUnitsListIdx) || selectedUnitsListIdx(end)>length(unitID)
        selectedUnitsListIdx=length(unitID);
    end
    selectedUnits=unitID(selectedUnitsListIdx);
end
% get 'raw data' excerpt
dataExcerpt.data=DisplayRawData(handles);
dataExcerpt.xTicks=linspace(0,handles.rec_info.samplingRate*2,4);
dataExcerpt.xTicklabels=linspace(round(handles.rawDataInfo.excerptLocation-...
    handles.rawDataInfo.excerptSize)/handles.rec_info.samplingRate,...
    round(handles.rawDataInfo.excerptLocation+handles.rawDataInfo.excerptSize)...
    /handles.rec_info.samplingRate,4);
dataExcerpt.location=handles.rawDataInfo.excerptLocation;
dataExcerpt.excerptSize=handles.rawDataInfo.excerptSize;
dataExcerpt.spkTimes=DisplayRasters(handles);

cd(handles.exportDir);
if isfield(handles,'Trials')
    TTLs=handles.Trials;
    save([handles.datFile(1:end-4) '_Ch' num2str(electrodeNum) '.mat'],...
        'waveForms','spikeTimes','unitsIdx','samplingRate','selectedUnits',...
        'TTLs','dataExcerpt');
else
    save([handles.datFile(1:end-4) '_Ch' num2str(electrodeNum) '.mat'],...
        'waveForms','spikeTimes','unitsIdx','samplingRate','selectedUnits',...
        'dataExcerpt');
end

% --- Executes on button press in LoadTTL_PB.
function LoadTTL_PB_Callback(hObject, eventdata, handles)
[handles.TTLFile,handles.TTLFileDir] = uigetfile({'*.*','All Files' },...
    'Select file containing TTL data',handles.exportDir);% '*.mat;*.hdf5','Export Formats';'*.dat;*.nev','Raw data';
handles.Trials = LoadTTL([handles.TTLFileDir handles.TTLFile]);
% Update handles structure
guidata(hObject, handles);


% --- Executes on button press in ShowTTL_PB.
function ShowTTL_PB_Callback(hObject, eventdata, handles)
% hObject    handle to ShowTTL_PB (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in ExportFigs_PB.
function ExportFigs_PB_Callback(hObject, eventdata, handles)
% hObject    handle to ExportFigs_PB (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in ClassifySU_PB.
function ClassifySU_PB_Callback(hObject, eventdata, handles)

channelNum=get(handles.SelectElectrode_LB,'value');

if get(handles.ShowAllUnits_RB,'value')
    helpdlg('All units are selected. Please select Single Units only','SU classification');
    return;
else
    unitID=str2num(get(handles.SelectUnit_LB,'string'));
    if unitID==0
        return;
    end
    selectedUnitsListIdx=get(handles.SelectUnit_LB,'value');
    if isempty(selectedUnitsListIdx) || selectedUnitsListIdx(end)>length(unitID)
        selectedUnitsListIdx=length(unitID);
    end
    selectedUnits=unitID(selectedUnitsListIdx);
end

for unit=1:length(selectedUnits)
    %find previous records
    sortID=handles.classification.SortID(handles.classification.Channel==channelNum &...
        handles.classification.UnitNumber==selectedUnits(unit));
    if isempty(sortID)
        sortID=size(handles.classification,1)+1;
    end
    handles.classification(sortID,:)={sortID,channelNum,selectedUnits(unit),'SU',''};
end
guidata(hObject, handles);

% --- Executes on button press in ClassifyMU_PB.
function ClassifyMU_PB_Callback(hObject, eventdata, handles)
channelNum=get(handles.SelectElectrode_LB,'value');

if get(handles.ShowAllUnits_RB,'value')
    helpdlg('All units are selected. Please select Single Units only','SU classification');
    return;
else
    unitID=str2num(get(handles.SelectUnit_LB,'string'));
    if unitID==0
        return;
    end
    selectedUnitsListIdx=get(handles.SelectUnit_LB,'value');
    if isempty(selectedUnitsListIdx) || selectedUnitsListIdx(end)>length(unitID)
        selectedUnitsListIdx=length(unitID);
    end
    selectedUnits=unitID(selectedUnitsListIdx);
end

for unit=1:length(selectedUnits)
    %find previous records
    sortID=handles.classification.SortID(handles.classification.Channel==channelNum &...
        handles.classification.UnitNumber==selectedUnits(unit));
    if isempty(sortID)
        sortID=size(handles.classification,1)+1;
    end
    handles.classification(sortID,:)={sortID,channelNum,selectedUnits(unit),'MU',''};
end
guidata(hObject, handles);

% --- Executes on button press in ClassifySpecial_PB.
function ClassifySpecial_PB_Callback(hObject, eventdata, handles)

prompt = {'Enter comment about special classification'};
dlg_title = '';
num_lines = 1;
defaultans = {''};
comment = inputdlg(prompt,dlg_title,num_lines,defaultans);

channelNum=get(handles.SelectElectrode_LB,'value');

if get(handles.ShowAllUnits_RB,'value')
    helpdlg('All units are selected. Please select Single Units only','SU classification');
    return;
else
    unitID=str2num(get(handles.SelectUnit_LB,'string'));
    if unitID==0
        return;
    end
    selectedUnitsListIdx=get(handles.SelectUnit_LB,'value');
    if isempty(selectedUnitsListIdx) || selectedUnitsListIdx(end)>length(unitID)
        selectedUnitsListIdx=length(unitID);
    end
    selectedUnits=unitID(selectedUnitsListIdx);
end

for unit=1:length(selectedUnits)
    %find previous records
    sortID=handles.classification.SortID(handles.classification.Channel==channelNum &...
        handles.classification.UnitNumber==selectedUnits(unit));
    if isempty(sortID)
        sortID=size(handles.classification,1)+1;
    end
    handles.classification(sortID,:)={sortID,channelNum,selectedUnits(unit),'Special',comment};
end
guidata(hObject, handles);

% --------------------------------------------------------------------
function Help_Menu_Callback(hObject, eventdata, handles)

% --------------------------------------------------------------------
function AddOptions_Menu_Callback(hObject, eventdata, handles)

% --------------------------------------------------------------------
function DisplayNtrodeMarkers_MenuItem_Callback(hObject, eventdata, handles)
if contains(get(handles.DisplayNtrodeMarkers_MenuItem,'Checked'),'off')
    set(handles.DisplayNtrodeMarkers_MenuItem,'Checked','on')
else
    set(handles.DisplayNtrodeMarkers_MenuItem,'Checked','off')
end

% --- Executes on button press in PB_LoadClass.
function PB_LoadClass_Callback(hObject, eventdata, handles)

% --- Executes on button press in PB_SaveClass.
function PB_SaveClass_Callback(hObject, eventdata, handles)

if size(handles.classification,1)>0
    handles.classification = sortrows(handles.classification,2);
    if exist([handles.fname  '_classification.xlsx'],'file')
        overwiteFile = questdlg('Classification file exits. Overwrite?', ...
            '','Yes','No','Yes');
        switch overwiteFile
            case 'Yes'
                delete([handles.fname  '_classification.xlsx'])
            case 'No'
                disp('Classification file not saved')
                return
        end
    end
    writetable(handles.classification,[handles.fname  '_classification.xlsx']);
end
