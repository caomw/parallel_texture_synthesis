%texture synthesis as per "Parallel Controllable Texture Synthesis"
% by Lefebvre and Hoppe
% Section 3.1 - basic scheme with gaussian stack

clear
gcp %initialize parallel processing

%preprocess_terrain_flow

load('mountains_with_precomputed_flow_vectors')
im_in(:,:,1)=(Z-mean(Z(:)))/max(Z(:));
im_in(:,:,2)=reshape(directions(:,1),256,256)/max(abs(directions(:,1)));
im_in(:,:,3)=reshape(directions(:,2),256,256)/max(abs(directions(:,2)));

neighbourhood = 5;
k_candidates = 10;
%add the neighbours of depressions to unusable pixel list
badX=repmat(depressions(:,1),1,neighbourhood*2+1)+repmat(-neighbourhood:neighbourhood,size(depressions,1),1);
badY=repmat(depressions(:,2),1,neighbourhood*2+1)+repmat(-neighbourhood:neighbourhood,size(depressions,1),1);
depression_neighbours=[];
for i=1:size(depressions,1)
    [X Y]=meshgrid(badX(i,:),badY(i,:));
    depression_neighbours=[depression_neighbours;X(:) Y(:)];
end
depressions=unique(depression_neighbours,'rows');

if(round(log2(size(im_in,1)))~=log2(size(im_in,1)) || round(log2(size(im_in,2)))~=log2(size(im_in,1)))
    disp('error, input texture must be square, of size 2^l')
end

%is the input toroidal?
toroidal = false;

[Nexemplar, candidates, pixels_in, m, input_levels] = preprocess_texture(im_in, neighbourhood, k_candidates, depressions);
save('mountain_256_preprocessed_all');

%the input and output need not be the same size
%the scale needs to be the same!
%The last output level will be the finest input level
output_size=256;%power of two
output_levels=log2(output_size);

%S has three dimensions:
% first and second are output x, y
% third is (x, y) in input
random_seed = 2;
rng(random_seed)

%if output_levels is less than input_levels, S_1 will be larger than 1
%if output_levels equals input_levels, S_1 will be [1 x 1 x 2]
%if otput_levels is more than input levels S_1 will be [1 x 1 x 2], but at a higher scale
level_difference=max(1,2^(output_levels-input_levels));
S=reshape(1+floor(rand(level_difference^2,2)*size(im_in,1)),[level_difference level_difference 2]);% <--random / deterministic --> S=reshape([16 16],[1 1 2]);
imagesc(reshape(pixels_in(sub2ind([m,m],S(:,:,1),S(:,:,2)),:),size(S,1),size(S,2),3))

corrections = 3;
%jitter parameter at each level
r=repmat(0.5,input_levels,1);

pixels_in=reshape(im_in,m^2,3);
close
tic
for l_out=max(1,input_levels-output_levels+1):input_levels
    S=upsample_s(S,m,l_out,toroidal);
    S=jitter_s(S, m, r(l_out), l_out, random_seed, toroidal);
    %pause(0.5)
    if(l_out>2)
        for c=1:corrections
            S=correct_s(S,Nexemplar{l_out},pixels_in,m,candidates{l_out},neighbourhood);
        end
    end
    output=reshape(pixels_in(sub2ind([m,m],S(:,:,1),S(:,:,2)),:),size(S,1),size(S,2),3);
    subplot(1,2,1)
    imagesc(output(end:-1:1,:,1))
    [X Y]=meshgrid(1:size(output,1),1:size(output,2));
    title(['ouptut at level ' num2str(l_out)])
    subplot(1,2,2)
    quiver(X,Y,output(:,:,2),output(:,:,3))
    axis([1 size(output,1) 1 size(output,2)])
    pause(0.3)%better than drawnow
end
toc
subplot(1,2,1)
title('final')
%imwrite(reshape(pixels_in(sub2ind([m,m],S(:,:,1),S(:,:,2)),:),size(S,1),size(S,2),3),'output_texture.png')