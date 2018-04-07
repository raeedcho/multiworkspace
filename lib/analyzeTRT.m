%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function results = analyzeTRT(trial_data,params)
% 
% For multiworkspace files, with dl and pm workspaces:
%   * Fits three different coordinate frame models to data from both workspaces
%   * Predicts firing rates from models on test data in both workspaces
%   * Compare predicted firing rates to actual firing rates in test data
%
% INPUTS:
%   trial_data : the struct
%   params     : parameter struct
%       .neural_signals  : which signals to calculate PDs for
%                           default: 'S1_FR'
%       .model_type     :   type of model to fit
%                           default; 'glm'
%       .glm_distribution : distribution to use for GLM
%                           default: 'poisson'
%       .model_eval_metric : Evaluation metric for models
%                           default: 'pr2'
%       .num_musc_pcs   :   Number of muscle principle components to use
%                           default: 5
%       .num_boots    : # bootstrap iterations to use
%                           default: 100
%       .verbose      :     Print diagnostic plots and information
%                           default: false
%
% OUTPUTS:
%   result  : results of analysis
%       .td_eval        : evaluation metrics for various models, in cell array
%                           rows: PM, DL, full
%                           cols: ext, ego, musc
%       .pdTables       : PD tables in cell array
%                           Rows: PM, DL
%                           Cols: ext_model, ego_model, musc_model, real
%       .tuning_curves  : tuning curves in cell array, same as pdTables
%       .shift_tables   : PD shift tables in cell array, cols same as above
%       .glm_info       : output from fitting GLMs to different models
%                           Cols: ext, ego, musc
%       .isTuned        : cell array of isTuned, one for each model, as above
%       .td_train       : trial data structure used to train models
%       .td_test        : trial data structures used to test models
%                           PM is first, DL is second
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function results = analyzeTRT(trial_data,params)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Set up
    % default parameters
    num_folds = 5;
    num_repeats = 20;
    verbose = false;
    if nargin > 1, assignParams(who,params); end % overwrite parameters

%% Preprocess trial_data structure
    % prep trial data by getting only rewards and trimming to only movements
    [~,td] = getTDidx(trial_data,'result','R');
    td = trimTD(td,{'idx_targetStartTime',0},{'idx_endTime',0});
    % bin data at 50ms
    td = binTD(td,5);
    % add in spherical coordinates
    td = addSphereHand2TD(td);
    % add firing rates rather than spike counts
    td = addFiringRates(td,struct('array','S1'));

    %% Do PCA on muscle space
    % do PCA on muscles, training on only the training set
    % need to drop a muscle: for some reason, PCA says rank of muscle kinematics matrix is 38, not 39.
    % PCAparams = struct('signals',{{'opensim',find(contains(td(1).opensim_names,'_len') & ~contains(td(1).opensim_names,'tricep_lat'))}},...
    %                     'do_plot',true);
    PCAparams = struct('signals',{{'opensim',find(contains(td(1).opensim_names,'_len'))}}, 'do_plot',verbose);
    [td,~] = getPCA(td,PCAparams);
    % temporary hack to allow us to do PCA on velocity too
    for i=1:length(td)
        td(i).opensim_len_pca = td(i).opensim_pca;
    end
    % get rid of superfluous PCA
    td = rmfield(td,'opensim_pca');
    % get velocity PCA
    % need to drop a muscle: for some reason, PCA says rank of muscle kinematics matrix is 38, not 39.
    % PCAparams_vel = struct('signals',{{'opensim',find(contains(td(1).opensim_names,'_muscVel') & ~contains(td(1).opensim_names,'tricep_lat'))}},...
    %                     'do_plot',true);
    PCAparams_vel = struct('signals',{{'opensim',find(contains(td(1).opensim_names,'_muscVel'))}}, 'do_plot',verbose);
    [td,~] = getPCA(td,PCAparams_vel);
    % temporary hack to allow us to save into something useful
    for i=1:length(td)
        td(i).opensim_muscVel_pca = td(i).opensim_pca;
    end
    % get rid of superfluous PCA
    td = rmfield(td,'opensim_pca');

    %% Get PCA for neural space
    PCAparams = struct('signals',{{'S1_spikes'}}, 'do_plot',verbose,'pca_recenter_for_proj',true,'sqrt_transform',true);
    [td,~] = getPCA(td,PCAparams);

%% Compile training and test sets
    % Split td into different workspaces (workspace 1 is PM and workspace 2 is DL)
    % also make sure we have balanced workspaces (slightly biases us towards early trials, but this isn't too bad)
    [~,td_pm] = getTDidx(td,'spaceNum',1);
    [~,td_dl] = getTDidx(td,'spaceNum',2);
    minsize = min(length(td_pm),length(td_dl));
    td_pm = td_pm(1:minsize);
    td_dl = td_dl(1:minsize);
    
    % get training and test set indices
    [train_idx,test_idx] = crossvalind('HoldOut',minsize,0.2);
    td_train = [td_pm(train_idx) td_dl(train_idx)];
    td_test = cell(2,1);
    td_test{1} = td_pm(test_idx);
    td_test{2} = td_dl(test_idx);

    [foldEval,foldTuning] = analyzeFold(td_train,td_test);

%% Package up outputs
    results = struct('model_names',{model_names},...
                        'td_eval',{td_eval},...
                        'tuningTable',{tuningTable},...
                        'glm_info',{glm_info},...
                        'td_train',{td_train},...
                        'td_test',{td_test});

    % results = struct('td_eval',{td_eval},...
    %                     'weight_tables',{weight_tables},...
    %                     %'pdTables',{pdTables},...
    %                     %'tuning_curves',{tuning_curves},...
    %                     %'shift_tables',{shift_tables},...
    %                     'glm_info',{glm_info},...
    %                     %'isTuned',{isTuned},...
    %                     'td_train',{td_train},...
    %                     'td_test',{td_test});


end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Sub functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [foldEval,foldTuning] = analyzeFold(td_train,td_test,params)
% ANALYZEFOLD analyze single fold of cross-validation set and return NeuronTable structure
%   with evaluation information for this fold
% 
% Inputs:
%   td_train - trial data structure with trials to be used for training
%   td_test - cell array of trial_data structures to be used for testing two workspaces
%   params - parameters struct
%       .
%
% Outputs:
%   foldEval - NeuronTable structure with evaluation information from fold
%       Each row corresponds to a neuron's evaluation over both workspaces
%       .{model_name}_eval - pseudo-R2 for a given model to that neuron
%       .{model_name}_PDshift - pseudo-R2 for a given model to that neuron
%   foldTuning - NeuronTable structure with tuning weight information from fold
%       Each row corresponds to a neuron evaluated in one of the workspaces
%       Columns past the header columns correspond to evaluation criteria:
%       .{model_name}_*Weight - extrinsic tuning weights for given model's
%           predicted firing rates
%       .{model_name}_tuningEval - pseudo-R2 for the tuning of each model's
%           predicted firing rates
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Set up
    % default parameters
    neural_signals = 'S1_FR';
    glm_distribution = 'poisson';
    model_eval_metric = 'pr2';
    model_type = 'glm';
    num_musc_pcs = 5;
    if nargin > 2
        assignParams(who,params);
    end % overwrite parameters

%% Fit models
    % set up parameters for models
    model_names = [strcat(model_type,{'_ext','_ego','_musc'},'_model') {'S1_FR'}];
    glm_params = cell(1,length(model_names)-1);
    glm_info = cell(1,length(model_names)-1);
    % cartesian hand coordinates for position and velocity
    opensim_hand_idx = find(contains(td_train(1).opensim_names,'_handPos') | contains(td_train(1).opensim_names,'_handVel'));
    glm_params{1} = struct('model_type',model_type,...
                            'model_name','ext_model',...
                            'in_signals',{{'opensim',opensim_hand_idx}},...
                            'out_signals',{{neural_signals}},'glm_distribution',glm_distribution);
    glm_params{2} = struct('model_type',model_type,...
                            'model_name','ego_model',...
                            'in_signals',{{'sphere_hand_pos';'sphere_hand_vel'}},...
                            'out_signals',{{neural_signals}},'glm_distribution',glm_distribution);
    glm_params{3} = struct('model_type',model_type,...
                            'model_name','musc_model',...
                            'in_signals',{{'opensim_len_pca',1:num_musc_pcs;'opensim_muscVel_pca',1:num_musc_pcs}},...
                            'out_signals',{{neural_signals}},'glm_distribution',glm_distribution);
    for modelnum = 1:length(model_names)-1
        [~,glm_info{modelnum}] = getModel(td_train,glm_params{modelnum});
    end

    % Predict firing rates
    for modelnum = 1:length(model_names)-1
        for spacenum = 1:2
            td_test{spacenum} = getModel(td_test{spacenum},glm_info{modelnum});
        end
    end

    % Evaluate model fits and add to foldEval table
    foldEval = makeNeuronTableStarter(td_train,struct('out_signal_names',td_train(1).S1_unit_guide));
    model_eval = cell(1,length(model_names)-1);
    eval_params = glm_info;
    for modelnum = 1:length(model_names)-1
        eval_params{modelnum}.eval_metric = model_eval_metric;
        eval_params{modelnum}.num_boots = 1;
        model_eval{modelnum} = array2table(squeeze(evalModel([td_test{2} td_test{1}],eval_params{modelnum}))',...
                                            'VariableNames',strcat(model_names(modelnum),'_eval'));
    end
    foldEval = horzcat(foldEval, model_eval{:});

%% Get extrinsic test tuning (to calculate later quantities from)
    tempTuningTable = cell(2,1);
    for spacenum = 1:2
        for modelnum = 1:length(model_names)
            % get tuning weights for each model
            weightParams = struct('out_signals',model_names(modelnum),'prefix',model_names{modelnum},...
                                    'out_signal_names',td_test{spacenum}(1).S1_unit_guide,...
                                    'do_eval_model',true,'meta',struct('spaceNum',spacenum));
            temp_weight_table = getTDModelWeights(td_test{spacenum},weightParams);

            % append table to full tuning table for space
            if modelnum == 1
                tempTuningTable{spacenum} = temp_weight_table;
            else
                tempTuningTable{spacenum} = join(tempTuningTable{spacenum}, temp_weight_table);
            end
        end
    end
    % smoosh space tables together
    foldTuning = vertcat(tempTuningTable{:});

%% Get PD shifts
    % get shifts from weights
    shift_tables = cell(1,length(model_names));
    for modelnum = 1:length(model_names)
        % select tables for each space
        [~,pm_foldTuning] = getNTidx(foldTuning,'spaceNum',1);
        [~,dl_foldTuning] = getNTidx(foldTuning,'spaceNum',2);

        % get PDs from pm and dl
        weights = pm_foldTuning.([model_names{modelnum} '_velWeight']);
        [pm_PDs,pm_moddepth] = cart2pol(weights(:,1),weights(:,2));
        weights = dl_foldTuning.([model_names{modelnum} '_velWeight']);
        [dl_PDs,dl_moddepth] = cart2pol(weights(:,1),weights(:,2));
        dPDs = minusPi2Pi(dl_PDs-pm_PDs);
        % use ratio because of glm link?
        dMod = (dl_moddepth)./(pm_moddepth);

        shift_tables{modelnum} = table(dPDs,dMod,'VariableNames',strcat(model_names{modelnum},{'_velPDShift','_velModdepthRatio'}));
    end

    foldEval = horzcat(foldEval,shift_tables{:});

end