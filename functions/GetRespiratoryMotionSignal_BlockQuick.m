function [Res_Signal1, Res_Signal_Long, para]=GetRespiratoryMotionSignal_BlockQuick(para,maskHeart,ResSort,recon_Car, sw);

recon_Res = zeros(size(recon_Car,1), size(recon_Car,2), floor(size(recon_Car,3)/2));

for t = 2:(size(recon_Res,3)-1)
  recon_Res(:,:,t) = (0.5*recon_Car(:,:,2*t-2)+recon_Car(:,:,2*t-1)+recon_Car(:,:,2*t)+...
      0.5*recon_Car(:,:,2*t+1))/3;
end

recon_Res(:,:,1) = (recon_Car(:,:,1)+recon_Car(:,:,2)+0.5*recon_Car(:,:,3))/2.5;
recon_Res(:,:,size(recon_Res,3)) = (0.5*recon_Car(:,:,size(recon_Res,3)-2)+...
    recon_Car(:,:,size(recon_Res,3)-1)+recon_Car(:,:,size(recon_Res,3)))/2.5;

[nx,ny,nt]=size(recon_Res);
%recon_Res = recon_Res .* repmat(imcomplement(maskHeart),[1 1 size(recon_Res,3)]);

border_img = squeeze(recon_Res(:,:,1));
border_size_big = 40;
border_size_small = 20;
for x = 1:size(recon_Res,1)
  for y = 1:size(recon_Res,2)
      if (x < border_size_big || x > size(recon_Res,1)-border_size_big) ...
         || (y < border_size_big || y > size(recon_Res,2)-border_size_big)
          if (x < border_size_small || x > size(recon_Res,1)-border_size_small) ...
             || (y < border_size_small || y > size(recon_Res,2)-border_size_small)
              border_img(x,y) = 0;
          else
              border_img(x,y) = 1;
          end
      else
          border_img(x,y) = 0;  
      end
  end
end

mask = max(real(recon_Res),[],3);
im_map = mat2gray(mask, [0 max(max(mask))]);

[counts, x] = imhist(im_map,256);
thresh = otsuthresh(counts);
%thresh = 0.75*thresh;
bw = im2bw(im_map, thresh);
se = strel('octagon',6);
bw_dilated = imdilate(bw,se);
bw_dilated = 1 - bw_dilated;


%border_img = border_img .* bw_dilated;
%recon_Res = recon_Res .* repmat(bw_dilated,[1 1 size(recon_Res,3)]);
recon_Res = recon_Res .* repmat(border_img,[1 1 size(recon_Res,3)]);

TR=para.TR*2;
time = TR:TR:nt*TR;
[FC_Index, F_X] = selectCardiacMotionFrequencies(para, nt);
[FR_Index, F_X] = selectRespMotionFrequencies(para, nt);

[nx,ny,nt]=size(recon_Res);
NN=floor(nx/12);k=0;
for ii=1:3:nx-NN
    for jj=1:3:ny-NN
        %tmp=gpuArray(abs(recon_Res(jj:jj+NN-1,ii:ii+NN-1,:)));
        tmp=abs(squeeze(recon_Res(jj:jj+NN-1,ii:ii+NN-1,:)));
        bin_tmp = tmp;
        bin_tmp(bin_tmp>0.0000001) = 1;
        s = sum(sum(sum(bin_tmp,1),2),3);
        if s/(NN*NN*nt) > 0.9
            k=k+1;
            Signal(:,k)=squeeze(sum(sum(tmp,1),2));
            %Signal(:,k)= Signal(:,k)/(NN*NN);
            %aux = gpuArray(Signal(:,k));
            temp=abs(fftshift(fft(Signal(:,k))));
            Signal_FFT(:,k) = temp/max(temp(:));
            %Signal_FFT(:,k)=gather(temp);clear temp tmp
        end
    end
end


Res_Peak=squeeze(Signal_FFT(FR_Index,:));
Car_Peak=squeeze(Signal_FFT(FC_Index,:));

ratio_Peak = max(Res_Peak)./max(Car_Peak);
[m,n]=find(Res_Peak==max(Res_Peak(:)));
%n = find(ratio_Peak == max(ratio_Peak));
%m = find(Res_Peak(:,n) == max(Res_Peak(:,n)));

disp(sprintf('Peak requency: %f', Res_Peak(m,n)));

ResFS=F_X(FR_Index);
ResFS=ResFS(m);

disp(sprintf('Respiratory motion frequency: %f', ResFS));
para.ResFS=ResFS;

Res_Signal=Signal(:,n);
Res_Signal_FFT=Signal_FFT(:,n);
Res_Signal=smooth(Res_Signal,7,'moving');
if sw
    Res_Signal= repmat(max(Res_Signal(:)), [length(Res_Signal),1]) - Res_Signal;
end


%close all
figure
subplot(2,1,1);plot(time,Res_Signal),title('Respiratory Motion Signal')
subplot(2,1,2);plot(F_X,Res_Signal_FFT),set(gca,'XLim',[-1.5 1.5]),set(gca,'YLim',[-.02 0.08]),
figure,imagescn(abs(recon_Res),[0 .003],[],[],3)


Res_Signal_Long = interp1( linspace(0,1,length(Res_Signal)), Res_Signal, linspace(0,1,para.nt), 'linear');
figure, plot(Res_Signal_Long)
span = double(idivide(int32(para.span),2)*8+1);
Res_Signal_Smooth = smooth(Res_Signal_Long, span, 'lowess');
%figure, plot(Res_Signal_Smooth)
[peak_values,peak_index]= findpeaks(double(Res_Signal_Smooth));
[valley_values,valley_index]= findpeaks(-double(Res_Signal_Smooth));
[peak_values,peak_index,valley_values,valley_index] = SnapExtrema( peak_values,peak_index,valley_values,valley_index, Res_Signal_Long, para.span);

avg_valley = abs(median(valley_values));
max_peak = abs(max(peak_values));

Res_Signal_Long = Res_Signal_Long - min(Res_Signal_Long);

  
Res_Signal1 = InvertRespCurve( Res_Signal_Long, peak_index, valley_index);    
figure, plot(Res_Signal1)