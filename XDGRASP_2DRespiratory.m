%%%%%%%%%%%%%
load_files=0;
%%%%%%%%%%%%%

addpath(genpath('functions'))
addpath(genpath('imageAnalysis'))

if(load_files)
clear all
clear classes
clc
%Load the files
%cd ('C:\Users\tchitiboi\Desktop\testDataSeptum\Pt7')
%load kdata.mat;
%load Traj.mat;
% load('/Users/rambr01/Documents/MATLAB/xdgrasp/meas_MID1221_CV_Cine_Radial_128_FID238330/Traj.mat')
% load('/Users/rambr01/Documents/MATLAB/xdgrasp/meas_MID1221_CV_Cine_Radial_128_FID238330/kdata.mat')
% load('/Users/rambr01/Documents/MATLAB/xdgrasp/meas_MID1221_CV_Cine_Radial_128_FID238330/ref.mat')
load('/Users/rambr01/Documents/MATLAB/xdgrasp/meas_MID2851_CV_Cine_Radial_128_FID232973/kdata.mat')
load('/Users/rambr01/Documents/MATLAB/xdgrasp/meas_MID2851_CV_Cine_Radial_128_FID232973/ref.mat')
load('/Users/rambr01/Documents/MATLAB/xdgrasp/meas_MID2851_CV_Cine_Radial_128_FID232973/Traj.mat')
end

[nx,ntviews,nc]=size(kdata);
coil=1:nc;%Coil elements used coil=[];coil=1:nc;
kdata=kdata(:,:,coil);
[nx,ntviews,nc]=size(kdata);

%Number of spokes in each cardiac phase
nline=15;

%Smoothing filter span
para.span=10;
para.flag=1;

%Cut is the number of spokes thrown away in the beginning of acquisition
%to achieve steady state
para.TR=TA/(ntviews+Cut)*nline;

% Total number of cardiac phases
para.nt=ntviews/nline;

%Generate time stamp for each cardiac phases
para=TimeStamp(para);

%%%Find coil element for Cardiac signal
%%% This may need some optimizations 
para.LF_H=0.6;para.HF_H=2;%%% initial heart rate range
para.LF_R=0.1;para.HF_R=0.4;%%% initial respiration rate range

%%%Calculate coil sensitivities
kdata=kdata.*repmat(sqrt(DensityComp),[1,1,nc]);
%load ref.mat
ref=ref(:,:,coil);
[~,b1]=adapt_array_2d(squeeze(ref));
b1=double(b1/max(abs(b1(:))));clear ref

%Get respiratory motion signal
[Res_Signal,para]=GetRespiratoryMotionSignal_Block(kdata,Traj,DensityComp,b1,nline,para,1);
Res_Signal=Res_Signal./max(Res_Signal(:));



%%%%%%%%%%%%%
% ResSort=0;
% fov_size=floor(nx/2);
% bKwicResp=0;
% %%%%%%%%%%%%%
% % if(~bKwicResp)
%     nline_res = nline*4;NProj=0;
%     [recon_Res,nt] = getReconForMotionDetection(kdata,Traj,DensityComp,b1,nline_res,fov_size,0,NProj,0);
%     [Res_Signal,para]=GetRespiratoryMotionSignal_Block(kdata,Traj,DensityComp,b1,nline,nline_res,para,ResSort,nt,recon_Res);
%     %[Res_Signal_new,para,U,S,V]=GetRespiratoryMotionSignal_Block_SVD(kdata,Traj,DensityComp,b1,nline,para,ResSort);
%     %%%%%%%%%%%%%
% else
%     %bKwic=1;nline_res = nline*4; NProj=nline*10-1;
%     nline_res = nline*4; NProj=nline*9-1;
%     [recon_Res_kwic,nt_kwic] = getReconForMotionDetection(kdata,Traj,DensityComp,b1,nline_res,fov_size,1,NProj,0);
%     [Res_Signal_kwic,para]=GetRespiratoryMotionSignal_Block(kdata,Traj,DensityComp,b1,nline,nline_res,para,ResSort,nt_kwic,recon_Res_kwic);
%     Res_Signal = Res_Signal_kwic;
% end
% Res_Signal=Res_Signal./max(Res_Signal(:));
%%%%%%%%%%%%%


%Get cardiac motion signal
%%%%%%%%%%%%%
bWithMask=1; 
bKwicCard=0;
bSW=0;
%%%%%%%%%%%%%
fov_size=floor(nx/3); 
%%%%%%%%%%%%%
if(~bKwicCard && ~bSW)
    bFilt=1;
    nline_res=nline*2;NProj=0;
    [recon_Car,nt] = getReconForMotionDetection(kdata,Traj,DensityComp,b1,nline_res,fov_size,0,0,1,0);
else
    if(bKwicCard)
        nline_res = nline*2; NProj=nline*10-5;
        [recon_Car,nt_kwic] = getReconForMotionDetection(kdata,Traj,DensityComp,b1,nline_res,fov_size,1,NProj,0,0); 
    else
        bFilt=1;
        nline_res = nline*2; NProj=nline*10-5;
        [recon_Car,nt_sw] = getReconForMotionDetection(kdata,Traj,DensityComp,b1,nline_res,fov_size,1,NProj,bFilt,1); 
    end
end
if(bWithMask)
    [Cardiac_Signal,para]=GetCardiacMotionSignal_HeartBlock(kdata,Traj,DensityComp,b1,nline,para,recon_Car);
    Cardiac_Signal=Cardiac_Signal./max(Cardiac_Signal(:));
else
    [Cardiac_Signal,para]=GetCardiacMotionSignal_Block(kdata,Traj,DensityComp,b1,nline,para,recon_Car);
    Cardiac_Signal=Cardiac_Signal./max(Cardiac_Signal(:));
end

para=ImproveCardiacMotionSignal(Cardiac_Signal,para);


% % %code for 9 cardiac phases 9 resp phases
Perr=9; %Perr=para.ntres;
Perc=para.CardiacPhase;
[kdata_Under,Traj_Under,DensityComp_Under,Res_Signal_Under]=DataSorting_Resp(kdata,Traj,DensityComp,Res_Signal,nline,para, Perr, Perc);

% [kdata_Under,Traj_Under,DensityComp_Under,Res_Signal_Under]=DataSorting_1CD(kdata,Traj,DensityComp,Res_Signal,nline,para);

%[recon_kwic,kdata_Under,Traj_Under,DensityComp_Under,kwicmask,kwicdcf] = apply_kwic(kdata_Under(:,:,),Traj_Under,DensityComp_Under,b1,nline,0);

% bKwicInit=1;
% if(~bKwicInit)
    %param.E=MCNUFFT_MP(Traj_Under,DensityComp_Under,b1);
    % param.E=MCNUFFT(Traj_Under,DensityComp_Under,b1);
    param.E=MCNUFFT_MP(Traj_Under,DensityComp_Under,b1);
    %param.E=MCNUFFT(Traj_Under,DensityComp_Under,b1);
    
    param.y=double(squeeze(kdata_Under));
    % param.Res_Signal=Res_Signal_Under;
    recon_GRASP=param.E'*param.y;
% else
%     recon_GRASP_kwic=initializeWithKwic(kdata_Under,Traj_Under,DensityComp_Under,b1,0);
% end

figure,imagescn(abs(recon_GRASP),[0 .003],[],[],3)

Weight1=0.01; %Cardiac
Weight2=0.03; %Resp
param.TVWeight=max(abs(recon_GRASP(:)))*Weight1;% Cardiac dimension 
param.L1Weight=max(abs(recon_GRASP(:)))*Weight2;% Respiration
% param.TV = TV_Temp;% TV along Cardiac dimension 
% param.TV = TV_Temp3D;% TV along Cardiac dimension 
% param.W  = TV_Temp2DRes;% TV along Respiratory dimension
% param.nite = 6;param.display = 1;
% param.TV = TV_Temp;% TV along Cardiac dimension 
param.TV = TV_Temp3D;% TV along Cardiac dimension 
param.W  = TV_Temp2DRes;% TV along Respiratory dimension
param.nite = 6;param.display = 1;


clear para Cardiac_Signal Cut DensityComp DensityComp_Under
clear Gating_Signal Gating_Signal_FFT Res_Signal Res_Signal_Under
clear TA Traj Traj_Under Weight1 Weight2 b1 kdata kdata_Under nc
clear nline ntviews nx N ans

%%%
clc
tic
for n=1:3
    recon_GRASP = CSL1NlCg(recon_GRASP,param);
end
time=toc;
time=time/60
recon_GRASP=abs(single(recon_GRASP));

[nx,ny,nt]=size(recon_GRASP);
for ii=1:nx
  for jj=1:ny
    recon_GRASP_TM(ii,jj,:)=medfilt1(recon_GRASP(ii,jj,:),5);
 end
end

figure,imagescn(abs(recon_GRASP),[0 .003],[],[],3)

figure,imagescn(abs(recon_GRASP_TM),[0 .003],[],[],3)

figure,imagescn(abs(recon_GRASP(90:90+70,90:90+70,:,:)),[0 .003],[],[],4)