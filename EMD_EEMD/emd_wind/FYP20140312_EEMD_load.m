%%
addpath('../dataset/load/');
addpath('../libsvm-3.11/');
addpath('../EMD_EEMD/');
addpath('../src/');

%% read data
HORIZON_array=[6 12 18 24 36 48];
ispoint=0;
numLags=96;
% import data
import_data=importdata('countryenergynsw_2011.csv'); % read data
time=datestr(import_data.textdata(2:end,1));

% correct na entry
load_data=na_correction(import_data.data);

%   skip
%   %% outlier detection
%   data=load_data;
%   skip
%   %% detect outliers
%   IQR_factor=1.5;
%   window=30;
%   threshold=10;
%   outlier_idx1=residual_IQR_outlier( load_data, IQR_factor );
%   outlier_idx2=window_mad_outlier( load_data, window, threshold );
%   % remove outliers
%   outlier_idx=intersect(outlier_idx1, outlier_idx2);
%   data = outlier_correction( load_data, outlier_idx );

% scale
[total_scaled_data, max_data, min_data]=scale_data( load_data,1,0,[],[] );
ts=timeseries(total_scaled_data, time);

% prepare for four typical months
starttime={'2011-01-01 00:00', '2011-02-01 00:00', '2011-03-01 00:00',...
           '2011-04-01 00:00', '2011-05-01 00:00', '2011-06-01 00:00', '2011-07-01 00:00',...
           '2011-08-01 00:00' '2011-09-01 00:00' '2011-10-01 00:00' '2011-11-01 00:00', '2011-12-01 00:00'};
endtime={'2011-01-31 23:30', '2011-02-28 23:30', '2011-03-31 23:30',...
           '2011-04-30 23:30', '2011-05-31 23:30', '2011-06-30 23:30', '2011-07-31 23:30',...
           '2011-08-31 23:30' '2011-09-30 23:30' '2011-10-31 23:30' '2011-11-30 23:50', '2011-12-31 23:30'};

% preallocate
result=cell(1,12);
pred=cell(1,12);
delays=cell(1,12);
SVR_param=cell(1,12);
for idx=1:12 % four typical months
    % form a TS
    scaled_ts=getsampleusingtime(ts, starttime{idx}, endtime{idx});
    scaled_data=scaled_ts.data;
    
    % use pacf to determine the feedback Delays.
    par_trn=parcorr(scaled_data, numLags);
    % select the top 10% quantile
    feedbackDelays=find(abs(par_trn)>quantile(abs(par_trn), 0.9));
    % if use pacf threshold:
    % feedbackDelays=find(abs(par_trn)>1.96/sqrt(length(trnIdx)));
    feedbackDelays=feedbackDelays-1;
    feedbackDelays=feedbackDelays(2:end);
    hiddenLayerSize=2*length(feedbackDelays);
    
    RATIO=[17, 7, 7]/31;
    
    [trn_data,trn_labels,tst_data,tst_labels]=ts2mat(scaled_data, (RATIO(1)+RATIO(2)), max(HORIZON_array), feedbackDelays,ispoint);
    
    trnIdx=1:(size(trn_data,1)+max(feedbackDelays));
    tstIdx=trnIdx(end)+(1:size(tst_data,1));
    
%     % EMD IMF series
%     IMF=emd(scaled_data);
%     IMF=IMF';
%     
    % CEEMD IMF series
    Nstd=0.2;
    NR=100;
    MaxIter=500;
    [ EEMD_IMF ] = myEEMD( scaled_data,Nstd,NR,MaxIter );
    EEMD_IMF=EEMD_IMF';
    
%     % CEEMDAN IMF series
%     NR=20;
%     [ CEEMDAN_IMF ] = ceemdan( scaled_data,Nstd,NR,MaxIter );
%     CEEMDAN_IMF=CEEMDAN_IMF';
%     
%     % pacf of imfs
%     for i=1:size(IMF, 2)
%         par=parcorr(IMF(1:round(size(IMF,1)*RATIO(1)),i),numLags);
%         tmp_lag=find(abs(par)>1.96/sqrt(round(length(IMF(:,i))*(RATIO(1)+RATIO(2)))))-1;
%         imf_lag{i}=setdiff(tmp_lag,0); % remove 0
%     end
    
    % pacf of imfs
    for i=1:size(EEMD_IMF, 2)
        par=parcorr(EEMD_IMF(1:round(size(EEMD_IMF,1)*RATIO(1)),i),numLags);
        tmp_lag=find(abs(par)>1.96/sqrt(round(length(EEMD_IMF(:,i))*(RATIO(1)+RATIO(2)))))-1;
        eemd_imf_lag{i}=setdiff(tmp_lag,0); % remove 0
    end
    
%     % pacf of imfs
%     for i=1:size(CEEMDAN_IMF, 2)
%         par=parcorr(CEEMDAN_IMF(1:round(size(CEEMDAN_IMF,1)*RATIO(1)),i),numLags);
%         tmp_lag=find(abs(par)>1.96/sqrt(round(length(CEEMDAN_IMF(:,i))*(RATIO(1)+RATIO(2)))))-1;
%         ceemdan_imf_lag{i}=setdiff(tmp_lag,0); % remove 0
%     end
%     
%     for i=1:size(IMF, 2)
%         [ IMF_trn_data{i}, IMF_trn_labels{i}, IMF_tst_data{i}, IMF_tst_labels{i} ]=ts2mat(IMF(:,i), (RATIO(1)+RATIO(2)), max(HORIZON_array), feedbackDelays,ispoint);
%     end
    
    for i=1:size(EEMD_IMF, 2)
        [ EEMD_IMF_trn_data{i}, EEMD_IMF_trn_labels{i}, EEMD_IMF_tst_data{i}, EEMD_IMF_tst_labels{i} ]=ts2mat(EEMD_IMF(:,i), (RATIO(1)+RATIO(2)), max(HORIZON_array), feedbackDelays,ispoint);
    end
    
%     for i=1:size(CEEMDAN_IMF, 2)
%         [ CEEMDAN_IMF_trn_data{i}, CEEMDAN_IMF_trn_labels{i}, CEEMDAN_IMF_tst_data{i}, CEEMDAN_IMF_tst_labels{i} ]=ts2mat(CEEMDAN_IMF(:,i), (RATIO(1)+RATIO(2)), max(HORIZON_array), feedbackDelays,ispoint);
%     end
    
    
    % plot IMF
%     myIMFplot(scaled_data(trnIdx), IMF(trnIdx,:));
    
    % statistical Signi test
%     myIMFstatistical_significance_test(IMF(trnIdx,:)', [0.05, 0.95]);
%     myIMFstatistical_significance_test(CEEMD_IMF(trnIdx,:)', [0.05, 0.95]);
%     myIMFstatistical_significance_test(CEEMDAN_IMF(trnIdx,:)', [0.05, 0.95]);
    
    
    %% Persistent
    % preallocation
    persistent_pred=zeros(size(tst_labels,1), max(HORIZON_array));
    
    PERIOD=48;
    for HORIZON=HORIZON_array
        persistent_pred(:,HORIZON)=scaled_data(tstIdx-PERIOD+HORIZON-1);
    end
    per_residue=tst_labels-repmat(persistent_pred(:,end), 1, max(HORIZON_array));
    [persistent_RMSE, persistent_sMAPE, persistent_MASE]=myErrorMeasure(tst_labels, repmat(persistent_pred(:,end), 1, max(HORIZON_array)), per_residue);
    
    
%     %% BP-NN
%     % preallocation
%     bpnn_pred=zeros(size(tst_labels,1), max(HORIZON_array));
%     
%     for HORIZON=HORIZON_array
%         [ bpnn_pred(:,HORIZON) ] = myANN( trn_data, trn_labels(:,HORIZON), tst_data, tst_labels(:,HORIZON), hiddenLayerSize, 'trainbfg');
%     end
%     [ BPNN_RMSE, BPNN_sMAPE, BPNN_MASE ]=myErrorMeasure(tst_labels, bpnn_pred, per_residue);
%     
%     %     %% RBFNN
%     %     % use newrb function, type `help newrb' for more info
%     %     goal=0.001; % set goal MSE
%     %     spread_range=0.1:0.1:0.9; % set spread
%     %
%     %     % preallocation
%     %     rbfnn_pred=zeros(size(tst_labels,1), max(HORIZON_array));
%     %
%     %     for HORIZON=HORIZON_array
%     %         [ rbfnn_pred(:,HORIZON) ] = ...
%     %             myRBFNN( trn_data, trn_labels(:,HORIZON), tst_data, tst_labels(:,HORIZON), goal, spread_range );
%     %     end
%     %
%     %     [RBFNN_RMSE, RBFNN_sMAPE, RBFNN_MASE]=myErrorMeasure(tst_labels, rbfnn_pred, per_residue);
%     %
%     %     % alternatively faster but performance not better
%     %     % RBFNN_pred2=myANN(trn_data, trn_labels, tst_data, tst_labels, 18 , 'trainlm', 'radbas');
%     %
%     %% SVR
%     % -t kernel_type : set type of kernel function (default 2)
%     %   0 -- linear: u'*v
%     %   1 -- polynomial: (gamma*u'*v + coef0)^degree
%     %   2 -- radial basis function: exp(-gamma*|u-v|^2)
%     %   3 -- sigmoid: tanh(gamma*u'*v + coef0)
%     %   4 -- precomputed kernel (kernel values in training_set_file)
    kernel=2; % rbf
    kernel1=0; % linear
    kernel2=1; % poly
    
    c_range=-3:4;
    g_range=(1:0.1:2)/size(trn_data,2);
    d_range=2;
    e_range=-4:-1;
%     
%     % preallocation
%     svr_pred=zeros(size(tst_labels,1), max(HORIZON_array));
%     
%     for HORIZON=HORIZON_array
%         %attr=numLags-lag{idx}+1; % attribute selected
%         [ model, CV_accuracy(HORIZON), best_param(HORIZON,:) ] = ...
%             grid_search_SVR( trn_data, trn_labels(:,HORIZON), kernel, c_range, g_range, d_range, e_range );
%         svr_pred(:,HORIZON)=svmpredict( tst_labels(:,HORIZON), tst_data, model );
%     end
%     [ SVR_RMSE, SVR_sMAPE, SVR_MASE ]=myErrorMeasure(tst_labels, svr_pred, per_residue);
%     
%     %% EMD-BPNN
%     % preallocation
%     ANN_IMF_pred=cell(1,size(IMF,2));
%     for i=1:size(IMF, 2)
%         % preallocation
%         tmp_emd_ann_pred=zeros(size(tst_labels,1), max(HORIZON_array));
%         
%         for HORIZON=HORIZON_array
%             [ tmp_emd_ann_pred(:,HORIZON), tmp_emdann_cv_mse(:,HORIZON) ] = ...
%                 myANN( IMF_trn_data{i}, IMF_trn_labels{i}(:,HORIZON), IMF_tst_data{i}, IMF_tst_labels{i}(:,HORIZON), hiddenLayerSize );
%         end
%         ANN_IMF_pred{i}=tmp_emd_ann_pred;
%         emdann_cv_mse{i}=tmp_emdann_cv_mse;
%     end
%     mat_ANNIMF_pred=cell2mat(ANN_IMF_pred);
%     
%     % preallocation
%     emdann_pred=zeros(size(tst_labels,1), max(HORIZON_array));
%     
%     for i=1:max(HORIZON_array)
%         [emdann_pred(:,i)]=sum(mat_ANNIMF_pred(:,i:max(HORIZON_array):end),2);
%     end
%     [ EMD_BPNN_RMSE, EMD_BPNN_sMAPE, EMD_BPNN_MASE ]=myErrorMeasure(tst_labels, emdann_pred, per_residue);
%     
%     %     %% EMD-RBFNN
%     %     % preallocation
%     %     RBF_IMF_pred=cell(1,size(IMF,2));
%     %     for i=2:size(IMF, 2)
%     %         for HORIZON=HORIZON_array
%     %             % preallocation
%     %         tmp_emd_rbfnn_pred=zeros(size(tst_labels,1), max(HORIZON_array));
%     %
%     %             [ tmp_emd_rbfnn_pred(:,HORIZON) ] = ...
%     %                 myRBFNN( IMF_trn_data{i}, IMF_trn_labels{i}(:,HORIZON), IMF_tst_data{i}, IMF_tst_labels{i}(:,HORIZON), goal, spread_range );
%     %         end
%     %         RBF_IMF_pred{i}=tmp_emd_rbfnn_pred;
%     %     end
%     %     mat_RBFIMF_pred=cell2mat(RBF_IMF_pred);
%     %
%     %     % preallocation
%     %     emdrbf_pred=zeros(size(tst_labels,1), max(HORIZON_array));
%     %
%     %     for i=1:max(HORIZON_array)
%     %         emdrbf_pred(:,i)=sum(mat_RBFIMF_pred(:,i:max(HORIZON_array):end),2);
%     %     end
%     %     [ EMD_RBFNN_RMSE, EMD_RBFNN_sMAPE, EMD_RBFNN_MASE ]=myErrorMeasure(tst_labels, emdrbf_pred, per_residue);
%     %
%     %% EMD-SVR
%     % preallocation
%     emd_pred=zeros(size(tst_labels,1), max(HORIZON_array));
%     IMF_pred=cell(1,size(IMF,2));
%     for i=1:size(IMF, 2)
%         tmp_IMF_pred=zeros(size(tst_labels,1), max(HORIZON_array));
%         for HORIZON=HORIZON_array
%             [ model, tmp_IMF_CV_accuracy(HORIZON), tmp_IMF_best_param(HORIZON,:) ] = ...
%                 grid_search_SVR( IMF_trn_data{i}, IMF_trn_labels{i}(:,HORIZON), kernel, c_range, g_range, d_range, e_range );
%             tmp_IMF_pred(:,HORIZON)=svmpredict( IMF_tst_labels{i}(:,HORIZON), IMF_tst_data{i}, model );
%         end
%         IMF_CV_accuracy{i}=tmp_IMF_CV_accuracy;
%         IMF_best_param{i}=tmp_IMF_best_param;
%         IMF_pred{i}=tmp_IMF_pred;
%     end
%     mat_IMF_pred=cell2mat(IMF_pred);
%     
%     for i=1:max(HORIZON_array)
%         emd_pred(:,i)=sum(mat_IMF_pred(:,i:max(HORIZON_array):end),2);
%     end
%     [ EMD_SVR_RMSE, EMD_SVR_sMAPE, EMD_SVR_MASE ]=myErrorMeasure(tst_labels, emd_pred, per_residue);
%     
    %% CEEMD-BPNN
    % preallocation
    EEMD_ANN_IMF_pred=cell(1,size(EEMD_IMF,2));
    for i=1:size(EEMD_IMF, 2)
        % preallocation
        tmp_eemd_ann_pred=zeros(size(tst_labels,1), max(HORIZON_array));
        
        for HORIZON=HORIZON_array
            [ tmp_eemd_ann_pred(:,HORIZON), tmp_eemdann_cv_mse(:,HORIZON) ] = ...
                myANN( EEMD_IMF_trn_data{i}, EEMD_IMF_trn_labels{i}(:,HORIZON), EEMD_IMF_tst_data{i}, EEMD_IMF_tst_labels{i}(:,HORIZON), hiddenLayerSize );
        end
        EEMD_ANN_IMF_pred{i}=tmp_eemd_ann_pred;
        eemdann_cv_mse{i}=tmp_eemdann_cv_mse;
    end
    mat_EEMD_ANNIMF_pred=cell2mat(EEMD_ANN_IMF_pred);
    
    % preallocation
    eemdann_pred=zeros(size(tst_labels,1), max(HORIZON_array));
    
    for i=1:max(HORIZON_array)
        eemdann_pred(:,i)=sum(mat_EEMD_ANNIMF_pred(:,i:max(HORIZON_array):end),2);
    end
    [ EEMD_BPNN_RMSE, EEMD_BPNN_sMAPE, EEMD_BPNN_MASE ]=myErrorMeasure(tst_labels, eemdann_pred, per_residue);
    
    %% CEEMD-SVR
    % preallocation
    eemd_pred=zeros(size(tst_labels,1), max(HORIZON_array));
    EEMD_IMF_pred=cell(1,size(EEMD_IMF,2));
    for i=1:size(EEMD_IMF, 2)
        tmp_EEMD_IMF_pred=zeros(size(tst_labels,1), max(HORIZON_array));
        for HORIZON=HORIZON_array
            [ model, tmp_EEMD_IMF_CV_accuracy(HORIZON), tmp_EEMD_IMF_best_param(HORIZON,:) ] = ...
                grid_search_SVR( EEMD_IMF_trn_data{i}, EEMD_IMF_trn_labels{i}(:,HORIZON), kernel, c_range, g_range, d_range, e_range );
            tmp_EEMD_IMF_pred(:,HORIZON)=svmpredict( EEMD_IMF_tst_labels{i}(:,HORIZON), EEMD_IMF_tst_data{i}, model );
        end
        EEMD_IMF_CV_accuracy{i}=tmp_EEMD_IMF_CV_accuracy;
        EEMD_IMF_best_param{i}=tmp_EEMD_IMF_best_param;
        EEMD_IMF_pred{i}=tmp_EEMD_IMF_pred;
    end
    mat_EEMD_IMF_pred=cell2mat(EEMD_IMF_pred);
    
    for i=1:max(HORIZON_array)
        eemd_pred(:,i)=sum(mat_EEMD_IMF_pred(:,i:max(HORIZON_array):end),2);
    end
    [ EEMD_SVR_RMSE, EEMD_SVR_sMAPE, EEMD_SVR_MASE ]=myErrorMeasure(tst_labels, eemd_pred, per_residue);
    
%     %% CEEMDAN-BPNN
%     % preallocation
%     CEEMDAN_ANN_IMF_pred=cell(1,size(CEEMDAN_IMF,2));
%     for i=1:size(CEEMDAN_IMF, 2)
%         % preallocation
%         tmp_ceemdan_ann_pred=zeros(size(tst_labels,1), max(HORIZON_array));
%         
%         for HORIZON=HORIZON_array
%             [ tmp_ceemdan_ann_pred(:,HORIZON), tmp_ceemdanann_cv_mse(:,HORIZON)] = ...
%                 myANN( CEEMDAN_IMF_trn_data{i}, CEEMDAN_IMF_trn_labels{i}(:,HORIZON), CEEMDAN_IMF_tst_data{i}, CEEMDAN_IMF_tst_labels{i}(:,HORIZON), hiddenLayerSize );
%         end
%         CEEMDAN_ANN_IMF_pred{i}=tmp_ceemdan_ann_pred;
%         ceemdanann_cv_mse{i}=tmp_ceemdanann_cv_mse;
%     end
%     mat_CEEMDAN_ANNIMF_pred=cell2mat(CEEMDAN_ANN_IMF_pred);
%     
%     % preallocation
%     ceemdanann_pred=zeros(size(tst_labels,1), max(HORIZON_array));
%     
%     for i=1:max(HORIZON_array)
%         ceemdanann_pred(:,i)=sum(mat_CEEMDAN_ANNIMF_pred(:,i:max(HORIZON_array):end),2);
%     end
%     [ CEEMDAN_BPNN_RMSE, CEEMDAN_BPNN_sMAPE, CEEMDAN_BPNN_MASE ]=myErrorMeasure(tst_labels, ceemdanann_pred, per_residue);
%     
%     %% CEEMDAN-SVR
%     % preallocation
%     ceemdan_pred=zeros(size(tst_labels,1), max(HORIZON_array));
%     CEEMDAN_IMF_pred=cell(1,size(CEEMDAN_IMF,2));
%     
%     for i=1:size(CEEMDAN_IMF, 2)
%         % preallocation
%         tmp_CEEMDAN_IMF_pred=zeros(size(tst_labels,1), max(HORIZON_array));
%         for HORIZON=HORIZON_array
%             [ model, tmp_CEEMDAN_IMF_CV_accuracy(HORIZON), tmp_CEEMDAN_IMF_best_param(HORIZON,:) ] = ...
%                 grid_search_SVR( CEEMDAN_IMF_trn_data{i}, CEEMDAN_IMF_trn_labels{i}(:,HORIZON), kernel, c_range, g_range, d_range, e_range );
%             tmp_CEEMDAN_IMF_pred(:,HORIZON)=svmpredict( CEEMDAN_IMF_tst_labels{i}(:,HORIZON), CEEMDAN_IMF_tst_data{i}, model );
%         end
%         CEEMDAN_IMF_CV_accuracy{i}=tmp_CEEMDAN_IMF_CV_accuracy;
%         CEEMDAN_IMF_best_param{i}=tmp_CEEMDAN_IMF_best_param;
%         CEEMDAN_IMF_pred{i}=tmp_CEEMDAN_IMF_pred;
%     end
%     mat_CEEMDAN_IMF_pred=cell2mat(CEEMDAN_IMF_pred);
%     
%     for i=1:max(HORIZON_array)
%         ceemdan_pred(:,i)=sum(mat_CEEMDAN_IMF_pred(:,i:max(HORIZON_array):end),2);
%     end
%     [ CEEMDAN_SVR_RMSE, CEEMDAN_SVR_sMAPE, CEEMDAN_SVR_MASE ]=myErrorMeasure(tst_labels, ceemdan_pred, per_residue);
    %%
    result{idx}=[persistent_RMSE, persistent_sMAPE, persistent_MASE
%         BPNN_RMSE, BPNN_sMAPE, BPNN_MASE
%         %         RBFNN_RMSE, RBFNN_sMAPE, RBFNN_MASE
%         SVR_RMSE, SVR_sMAPE, SVR_MASE
%         EMD_BPNN_RMSE, EMD_BPNN_sMAPE, EMD_BPNN_MASE
%         %         EMD_RBFNN_RMSE, EMD_RBFNN_sMAPE, EMD_RBFNN_MASE
%         EMD_SVR_RMSE, EMD_SVR_sMAPE, EMD_SVR_MASE
        EEMD_BPNN_RMSE, EEMD_BPNN_sMAPE, EEMD_BPNN_MASE
        EEMD_SVR_RMSE, EEMD_SVR_sMAPE, EEMD_SVR_MASE
%         CEEMDAN_BPNN_RMSE, CEEMDAN_BPNN_sMAPE, CEEMDAN_BPNN_MASE
%         CEEMDAN_SVR_RMSE, CEEMDAN_SVR_sMAPE, CEEMDAN_SVR_MASE
        ];
    delays{idx}=feedbackDelays;
%     CV_ACC{idx}=CV_accuracy;
%     B_P{idx}=best_param;
%     IMF_CV_ACC{idx}=IMF_CV_accuracy;
%     IMF_CV_MSE{idx}=emdann_cv_mse;
%     IMF_B_P{idx}=IMF_best_param;
    EEMD_CV_ACC{idx}=EEMD_IMF_CV_accuracy;
    EEMD_CV_MSE{idx}=eemdann_cv_mse;
    EEMD_B_P{idx}=EEMD_IMF_best_param;
%     CEEMDAN_CV_ACC{idx}=CEEMDAN_IMF_CV_accuracy;
%     CEEMDAN_CV_MSE{idx}=ceemdanann_cv_mse;
%     CEEMDAN_B_P{idx}=CEEMDAN_IMF_best_param;
    pred{idx}=[persistent_pred, eemdann_pred, eemd_pred];
end
save('result_FYP_load_20140423.mat', 'result', 'pred','delays','EEMD_CV_ACC', 'EEMD_B_P', 'EEMD_CV_MSE' );
