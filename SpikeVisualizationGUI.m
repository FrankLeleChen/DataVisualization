function varargout = SpikeVisualizationGUI(varargin)
% MATLAB code for SpikeVisualizationGUI.fig


% Last Modified by GUIDE v2.5 10-Jun-2016 17:55:40

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
function SpikeVisualizationGUI_OpeningFcn(hObject, eventdata, handles, varargin)

% Choose default command line output for SpikeVisualizationGUI
handles.output = hObject;

if ~isempty(varargin)
    handles=catstruct(handles,varargin{:}); % catstruct available here:
    % http://www.mathworks.com/matlabcentral/fileexchange/7842-catstruct
    
    if isfield(handles,'fname')
        set(handles.FileName,'string',handles.fname(1:end-4));
    else
        set(handles.FileName,'string','');
    end
else
    % open user input window
end

handles=LoadSpikes(handles);

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes SpikeVisualizationGUI wait for user response (see UIRESUME)
% uiwait(handles.figure1);

%% Load data function
function handles=LoadSpikes(handles)
% function declaration
axis_name= @(x) sprintf('Chan %.0f',x);
if strcmp(handles.fname,'')
    set(handles.FileName,'string','')
else
    cd(handles.exportdir);
    userinfo=UserDirInfo;
    exportDirListing=dir;
    handles.spikeFile={exportDirListing(~cellfun('isempty',cellfun(@(x) strfind(x,'_spikes'),...
        {exportDirListing.name},'UniformOutput',false))).name};
    if size(handles.spikeFile,2)>1
        nameComp=cellfun(@(x) sum(ismember(x,handles.fname)) ,handles.spikeFile);
        if abs(diff(nameComp))<2 %that can be tricky for some files
            %select the most recent
            fileDates=datenum({exportDirListing(~cellfun('isempty',cellfun(@(x) strfind(x,'_spikes'),...
                {exportDirListing.name},'UniformOutput',false))).date});
            handles.spikeFile=handles.spikeFile{fileDates==max(fileDates)};
        else
            handles.spikeFile=handles.spikeFile{nameComp==max(nameComp)};
        end
    else
        handles.spikeFile=handles.spikeFile{:};
    end
    set(handles.FileName,'string',[handles.exportdir userinfo.slash handles.spikeFile])
    
    %% Load spike data
    spikeData=load(handles.spikeFile);
    handles=catstruct(handles,spikeData);
    clear spikeData;
    
    %% Set number of electrodes and units, select electrode with most units and spikes
    set(handles.SelectElectrode_LB,'string',num2str(handles.Spikes.Offline_Threshold.electrode'));
    if isfield(handles.Spikes,'Online_Sorting') || isfield(handles.Spikes,'Offline_Sorting')
        if isfield(handles.Spikes,'Offline_Sorting') %preferred
            set(handles.Spikes_SortOff_RB,'value',1);
            set(handles.Spikes_SortOn_RB,'value',0);
            handles.Units=handles.Spikes.Offline_Sorting.Units;
            handles.SpikeTimes=handles.Spikes.Offline_Sorting.SpikeTimes;
            handles.Waveforms=handles.Spikes.Offline_Sorting.Waveforms;
        else
            set(handles.Spikes_SortOff_RB,'value',0);
            set(handles.Spikes_SortOn_RB,'value',1);
            handles.Spikes.inGUI.Units=handles.Spikes.Online_Sorting.Units;
            handles.Spikes.inGUI.SpikeTimes=handles.Spikes.Online_Sorting.SpikeTimes;
            handles.Spikes.inGUI.Waveforms=handles.Spikes.Online_Sorting.Waveforms;
        end
        numUnits=cellfun(@(x) sum(length(x)*unique(x)), handles.Spikes.inGUI.Units);
        electrodeNum=find(numUnits==max(numUnits),1);
        set(handles.SelectElectrode_LB,'value',electrodeNum);
    else
        set(handles.SelectElectrode_LB,'value',1)
    end
    
    %% initialize variables
    unitsIdx=handles.Spikes.inGUI.Units{electrodeNum};
    waveForms=handles.Spikes.inGUI.Waveforms{electrodeNum};
    % how many units on that electrode?
    unitsID=unique(unitsIdx); %number of clustered units
    set(handles.SelectUnit_LB,'string',num2str(unitsID'));
    set(handles.SelectUnit_LB,'value',find(unitsID~=0));
    
    %% take out big ouliers
    WFmeanZ=mean(abs(zscore(single(waveForms'))),2);
    figure('name', 'Artifacts','position',[30   500   500   400]);
    plot(waveForms(:,WFmeanZ>6)','linewidth',2.5); hold on;
    plot(mean(waveForms,2),'linewidth',2.5);
    legend({'Artifact','Mean waveforms'});
    title('Potential artifacts removed, mean sigma > 6');
    handles.Spikes.inGUI.Units{electrodeNum}(WFmeanZ>6)=-9;%artifacts
    
    % here's how this can work:
    %     Spikes detected from threshold are the benchmark (unit code = 0).
    %     May want to extract waveforms, but most important is the time.
    %     Sorted units (whatever the source) "color" those units. One spike per ms max.
    handles=Plot_Unsorted_WF(handles);
    handles=Plot_Sorted_WF(handles);
    Plot_Mean_WF(handles);
    Plot_Raster_TW(handles);
end

%% Plot Unsorted Spikes
function handles=Plot_Unsorted_WF(handles)
electrodeNum=get(handles.SelectElectrode_LB,'value');
waveForms=handles.Spikes.inGUI.Waveforms{electrodeNum};
unitsIdx=handles.Spikes.inGUI.Units{electrodeNum};
samplingRate=handles.Spikes.Online_Sorting.samplingRate(electrodeNum);
%% Plot unsorted spikes
if sum(unitsIdx==0)>2000 %then only plot subset of waveforms
    subset=find(unitsIdx==0);
    handles.subset{1}=subset(1:round(sum(unitsIdx==0)/2000):end);
else
    handles.subset{1}=find(unitsIdx==0);
end
axes(handles.UnsortedUnits_Axes); hold on;colormap lines; cmap=colormap;
cla(handles.UnsortedUnits_Axes);
set(handles.UnsortedUnits_Axes,'Visible','on');
plot(waveForms(:,handles.subset{1}),'linewidth',1,'Color',[0 0 0 0.2]);
lineH=flipud(findobj(gca,'Type', 'line'));
% childH=flipud(get(gca,'Children'));
for lineTag=1:size(lineH,1)
    lineH(lineTag).Tag=num2str(handles.subset{1}(lineTag));
end
% foo=reshape([lineH.YData],size([lineH.YData],2)/size(lineH,1),size(lineH,1));
% faa=reshape([childH.YData],size([childH.YData],2)/size(childH,1),size(childH,1));
% lineH(80).Tag
% figure; hold on;
% plot(foo(:,80));
% plot(waveForms(:,handles.subset{1}(80)));
% [lineH.Tag]=deal(num2str(handles.subset{1}));
set(gca,'xtick',linspace(0,size(waveForms(:,handles.subset{1}),1),5),...
    'xticklabel',round(linspace(-round(size(waveForms(:,handles.subset{1}),1)/2),...
    round(size(waveForms(:,handles.subset{1}),1)/2),5)/(double(samplingRate)/1000),2),'TickDir','out');
% legend('Unclustered waveforms','location','southeast')
axis('tight');box off;
xlabel('Time (ms)')
ylabel('Voltage (0.25uV)')
set(gca,'Color','white','FontSize',10,'FontName','calibri');

%% Plot clusters
function handles=Plot_Sorted_WF(handles)
electrodeNum=get(handles.SelectElectrode_LB,'value');
waveForms=handles.Spikes.inGUI.Waveforms{electrodeNum};
unitsIdx=handles.Spikes.inGUI.Units{electrodeNum};
samplingRate=handles.Spikes.Online_Sorting.samplingRate(electrodeNum);
% selected unit ids
axes(handles.SortedUnits_Axes); hold on;colormap lines; cmap=colormap;
cla(handles.SortedUnits_Axes);
set(handles.SortedUnits_Axes,'Visible','on');
if get(handles.ShowAllUnits_RB,'value')
    unitID=str2num(get(handles.SelectUnit_LB,'string'));
    selectedUnitsListIdx=find(unitID>0);
    selectedUnits=unitID(selectedUnitsListIdx);
else
    unitID=str2num(get(handles.SelectUnit_LB,'string'));
    selectedUnitsListIdx=get(handles.SelectUnit_LB,'value');
    selectedUnits=unitID(selectedUnitsListIdx);
end
for unitP=1:length(selectedUnits)
    if sum(unitsIdx==selectedUnits(unitP))>2000 %then only plot subset of waveforms
        subset=find(unitsIdx==selectedUnits(unitP));
        handles.subset{selectedUnitsListIdx(unitP)}=subset(1:round(sum(unitsIdx==selectedUnits(unitP))/2000):end);
    else
        handles.subset{selectedUnitsListIdx(unitP)}=find(unitsIdx==selectedUnits(unitP));
    end
    plot(waveForms(:,handles.subset{selectedUnitsListIdx(unitP)}),'linewidth',1,'Color',[cmap(unitID(selectedUnitsListIdx(unitP)),:),0.4]);
end
set(gca,'xtick',linspace(0,size(waveForms(:,handles.subset{selectedUnitsListIdx(unitP)}),1),5),...
    'xticklabel',round(linspace(-round(size(waveForms(:,handles.subset{selectedUnitsListIdx(unitP)}),1)/2),...
    round(size(waveForms(:,handles.subset{selectedUnitsListIdx(unitP)}),1)/2),5)/(double(samplingRate)/1000),2),'TickDir','out');
% legend('Unclustered waveforms','location','southeast')
axis('tight');box off;
xlabel('Time (ms)')
ylabel('Voltage (0.25uV)')
set(gca,'Color','white','FontSize',10,'FontName','calibri');
hold off

%% Plot mean waveforms
function Plot_Mean_WF(handles)
electrodeNum=get(handles.SelectElectrode_LB,'value');
waveForms=handles.Spikes.inGUI.Waveforms{electrodeNum};
unitsIdx=handles.Spikes.inGUI.Units{electrodeNum};
samplingRate=handles.Spikes.Online_Sorting.samplingRate(electrodeNum);
axes(handles.MeanSortedUnits_Axes); hold on;colormap lines; cmap=colormap;
cla(handles.MeanSortedUnits_Axes);
set(handles.MeanSortedUnits_Axes,'Visible','on');
if get(handles.ShowAllUnits_RB,'value')
    unitID=str2num(get(handles.SelectUnit_LB,'string'));
    selectedUnitsListIdx=find(unitID>0);
    selectedUnits=unitID(selectedUnitsListIdx);
else
    unitID=str2num(get(handles.SelectUnit_LB,'string'));
    selectedUnitsListIdx=get(handles.SelectUnit_LB,'value');
    selectedUnits=unitID(selectedUnitsListIdx);
end
for unitP=1:length(selectedUnits)
    selectWF=single(waveForms(:,handles.subset{selectedUnitsListIdx(unitP)})');
    if ~isnan(mean(selectWF))
        plot(mean(selectWF),'linewidth',2,'Color',[cmap(unitID(selectedUnitsListIdx(unitP)),:),0.7]);
        wfSEM=std(selectWF)/ sqrt(size(selectWF,2)); %standard error of the mean
        wfSEM = wfSEM * 1.96; % 95% of the data will fall within 1.96 standard deviations of a normal distribution
        patch([1:length(wfSEM),fliplr(1:length(wfSEM))],...
            [mean(selectWF)-wfSEM,fliplr(mean(selectWF)+wfSEM)],...
            cmap(unitID(selectedUnitsListIdx(unitP)),:),'EdgeColor','none','FaceAlpha',0.2);
        %duplicate mean unit over unsorted plot
        %             plot(handles.UnsortedUnits_Axes,mean(selectWF),'linewidth',2,'Color',cmap(unitP,:));
        if unitP==1
            delete(findobj(handles.UnsortedUnits_Axes,'Type', 'patch'));
        end
        patch([1:length(wfSEM),fliplr(1:length(wfSEM))],...
            [mean(selectWF)-wfSEM,fliplr(mean(selectWF)+wfSEM)],...
            cmap(unitID(selectedUnitsListIdx(unitP)),:),'EdgeColor','none','FaceAlpha',0.5,'Parent', handles.UnsortedUnits_Axes);
    end
end
set(gca,'xtick',linspace(0,size(waveForms(:,handles.subset{selectedUnitsListIdx(unitP)}),1),5),...
    'xticklabel',round(linspace(-round(size(waveForms(:,handles.subset{selectedUnitsListIdx(unitP)}),1)/2),...
    round(size(waveForms(:,handles.subset{selectedUnitsListIdx(unitP)}),1)/2),5)/(double(samplingRate)/1000),2),'TickDir','out');
% legend('Unclustered waveforms','location','southeast')
axis('tight');box off;
xlabel('Time (ms)')
ylabel('Voltage (0.25uV)')
set(gca,'Color','white','FontSize',10,'FontName','calibri');
hold off

function  Plot_Raster_TW(handles)
%% plot rasters
electrodeNum=get(handles.SelectElectrode_LB,'value');
spikeTimes=handles.Spikes.inGUI.SpikeTimes{electrodeNum};
% downsample to 1 millisecond bins
%         Spikes.Offline_Threshold.samplingRate(ChExN,2)=1000;
%         Spikes.Offline_Threshold.type{ChExN,2}='downSampled';
%         spikeTimeIdx=zeros(1,size(Spikes.Offline_Threshold.data{ChExN,1},2));
%         spikeTimeIdx(Spikes.Offline_Threshold.data{ChExN,1})=1;
%         spikeTimes=find(Spikes.Offline_Threshold.data{ChExN,1});
%         binSize=1;
%         numBin=ceil(size(spikeTimeIdx,2)/(Spikes.Offline_Threshold.samplingRate(ChExN,1)/Spikes.Offline_Threshold.samplingRate(ChExN,2))/binSize);
%         % binspikeTime = histogram(double(spikeTimes), numBin); %plots directly histogram
%         [Spikes.Offline_Threshold.data{ChExN,2},Spikes.Offline_Threshold.binEdges{ChExN}] = histcounts(double(spikeTimes), linspace(0,size(spikeTimeIdx,2),numBin));
%         Spikes.Offline_Threshold.data{ChExN,2}(Spikes.Offline_Threshold.data{ChExN,2}>1)=1; %no more than 1 spike per ms
%
% plot 10 sec or 2000 waveforms max

% --- Executes on mouse press over axes background.
function UnsortedUnits_Axes_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to UnsortedUnits_Axes (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

electrodeNum=get(handles.SelectElectrode_LB,'value');

%% initialize variables
unitsIdx=find(handles.Spikes.inGUI.Units{electrodeNum}==0);
% waveForms=handles.Spikes.inGUI.Waveforms{electrodeNum};
% spikeTimes=handles.Spikes.inGUI.SpikeTimes{electrodeNum};
% samplingRate=handles.Spikes.Online_Sorting.samplingRate(electrodeNum);

lineH=findobj(gca,'Type', 'line');

%adjust number of waveforms to those displayed.
% or pull it from handles
find(cellfun(@(x) strcmp(x,'on'), {lineH.Visible}));

waveForms=fliplr(reshape([lineH.YData],size([lineH.YData],2)/size(lineH,1),size(lineH,1)));
waveForms=waveForms';%one waveform per row

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
% foo=handles.Spikes.inGUI.Waveforms{electrodeNum}; foo=foo';
% figure;plot(foo(unitsIdx(logical(clusterClasses)),:)');hold on
% plot(lineH(flip(logical(clusterClasses))).YData)
handles.Spikes.inGUI.Units{electrodeNum}(unitsIdx(logical(clusterClasses)))=...
    clusterClasses(logical(clusterClasses));
unitsID=unique(handles.Spikes.inGUI.Units{electrodeNum});
set(handles.SelectUnit_LB,'String',num2str(unitsID(unitsID>=0)'))
if get(handles.ShowAllUnits_RB,'value')
    handles=Plot_Sorted_WF(handles);
    Plot_Mean_WF(handles);
end
%  Update handles structure
guidata(hObject, handles);

%% --- Executes on selection change in SelectElectrode_LB.
function SelectElectrode_LB_Callback(hObject, eventdata, handles)
% hObject    handle to SelectElectrode_LB (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

%% Get chanel and unit selection
%     channelMenu=get(handles.SelectElectrode_LB,'string');
%     channelSelected=get(handles.SelectElectrode_LB,'value');
%     channelSelected=channelMenu(channelSelected);
%
%     unitMenu=get(handles.SelectUnit_LB,'string');
%     unitsSelected=get(handles.SelectUnit_LB,'value');
%     unitsSelected=unitMenu(unitsSelected);


% Hints: contents = cellstr(get(hObject,'String')) returns SelectElectrode_LB contents as cell array
%        contents{get(hObject,'Value')} returns selected item from SelectElectrode_LB

% --- Executes on selection change in SelectUnit_LB.

function SelectUnit_LB_Callback(hObject, eventdata, handles)
set(handles.ShowAllUnits_RB,'value',0)
if strcmp(get(gcf,'SelectionType'),'normal')
    %     = cellstr(get(hObject,'String'))
    %        contents{get(hObject,'Value')}
    handles=Plot_Sorted_WF(handles);
    Plot_Mean_WF(handles);
    % elseif strcmp(get(gcf,'SelectionType'),'open') % double click
    % else
    %  Update handles structure
    guidata(hObject, handles);
end

% --- Executes on button press in ShowAllUnits_RB.
function ShowAllUnits_RB_Callback(hObject, eventdata, handles)
if get(hObject,'Value')
    handles=Plot_Sorted_WF(handles);
    Plot_Mean_WF(handles);
end

% --- Executes on mouse press over axes background.
function MeanSortedUnits_Axes_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to MeanSortedUnits_Axes (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% InteractiveClassification; % viewClasses=0

% unitsIdx
%  Update handles structure
guidata(hObject, handles);

%% --- Outputs from this function are returned to the command line.
function varargout = SpikeVisualizationGUI_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


%% --- Executes on button press in Spikes_SortOff_RB.
function Spikes_SortOff_RB_Callback(hObject, eventdata, handles)
% hObject    handle to Spikes_SortOff_RB (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of Spikes_SortOff_RB


%% --- Executes on button press in radiobutton2.
function radiobutton2_Callback(hObject, eventdata, handles)
% hObject    handle to radiobutton2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of radiobutton2



function edit1_Callback(hObject, eventdata, handles)
% hObject    handle to edit1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit1 as text
%        str2double(get(hObject,'String')) returns contents of edit1 as a double


%% --- Executes during object creation, after setting all properties.
function edit1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


%% --- Executes on selection change in listbox1.
function listbox1_Callback(hObject, eventdata, handles)
% hObject    handle to listbox1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox1 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox1


%% --- Executes during object creation, after setting all properties.
function listbox1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


%% --- Executes on button press in pushbutton1.
function pushbutton1_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

%% --- Executes during object creation, after setting all properties.
function SelectElectrode_LB_CreateFcn(hObject, eventdata, handles)
% hObject    handle to SelectElectrode_LB (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


%% --- Executes on slider movement.
function slider1_Callback(hObject, eventdata, handles)
% hObject    handle to slider1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


%% --- Executes during object creation, after setting all properties.
function slider1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


%% --- Executes on button press in pushbutton3.
function pushbutton3_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


%% --- Executes on button press in pushbutton4.
function pushbutton4_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


%% --- Executes on button press in pushbutton5.
function pushbutton5_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


%% --- Executes on button press in Spikes_Th_RB.
function Spikes_Th_RB_Callback(hObject, eventdata, handles)
% hObject    handle to Spikes_Th_RB (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of Spikes_Th_RB


%% --- Executes on selection change in listbox2.
function listbox2_Callback(hObject, eventdata, handles)
% hObject    handle to listbox2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox2 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox2


%% --- Executes during object creation, after setting all properties.
function listbox2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit2_Callback(hObject, eventdata, handles)
% hObject    handle to edit2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit2 as text
%        str2double(get(hObject,'String')) returns contents of edit2 as a double


%% --- Executes during object creation, after setting all properties.
function edit2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


%% --- Executes on button press in Spikes_SortOn_RB.
function Spikes_SortOn_RB_Callback(hObject, eventdata, handles)
% hObject    handle to Spikes_SortOn_RB (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of Spikes_SortOn_RB


%% --- Executes on button press in PB_GetSortedSpikes.
function PB_GetSortedSpikes_Callback(hObject, eventdata, handles)
% hObject    handle to PB_GetSortedSpikes (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% --- Executes during object creation, after setting all properties.
function SelectUnit_LB_CreateFcn(hObject, eventdata, handles)
% hObject    handle to SelectUnit_LB (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on slider movement.
function TW_slider_Callback(hObject, eventdata, handles)
% hObject    handle to TW_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function TW_slider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to TW_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in TWplus_PB.
function TWplus_PB_Callback(hObject, eventdata, handles)
% hObject    handle to TWplus_PB (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in TWminus_PB.
function TWminus_PB_Callback(hObject, eventdata, handles)
% hObject    handle to TWminus_PB (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in TWall_PB.
function TWall_PB_Callback(hObject, eventdata, handles)
% hObject    handle to TWall_PB (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in LoadFile_PB.
function LoadFile_PB_Callback(hObject, eventdata, handles)
% hObject    handle to LoadFile_PB (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in Reload_PB.
function Reload_PB_Callback(hObject, eventdata, handles)
% hObject    handle to Reload_PB (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



