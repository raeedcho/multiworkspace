%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This script makes plots from results given by analyzeTRT
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%% Main line figures %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Figure 1 - Task and classic analysis methods
    % 1a - Monkey using manipulandum (in illustrator)

    % 1b - example movements in two workspaces (with neural firing dots?)
    % First, get example trials
    [~,td_pm_ex] = getTDidx(trial_data,'spaceNum',1,'result','R','rand',1);
    [~,td_dl_ex] = getTDidx(trial_data,'spaceNum',2,'result','R','rand',1);
    % trim to just go from target start to end
    td_ex = trimTD([td_pm_ex td_dl_ex],{'idx_ctHoldTime',0},{'idx_endTime',0});
    % plot the example trials
    figure('defaultaxesfontsize',18)
    plotTRTTrials(td_ex);
    % plot neural firing?
    unit_idx = 1;
    plotSpikesOnHandle(td_ex,struct('unit_idx',unit_idx,'spikespec','b.','spikesize',10));
    % plot of same muscle movement given different Jacobians?

    % Switch to classical PDs?
    % 1c - example directional rasters and tuning curves?

%% Figure 2 - Analysis block diagrams
    % 2a - Block diagram of three different models

    % 2b - Breaking up the data into training and testing sets

    % 2c - Example neural predictions for each model

%% Set up plotting variables
    datadir = '/home/raeed/Wiki/Projects/limblab/multiworkspace/data/Results/Encoding';
    % filename = {'Han_20171101_TRT_encodingResults_run20180809.mat','Chips_20170915_TRT_encodingResults_run20180809.mat','Lando_20170802_encodingResults_run20180809.mat'};
    % filename = {'Han_20171101_TRT_encodingResults_allModels_run20180912.mat','Chips_20170915_TRT_encodingResults_allModels_run20180912.mat','Lando_20170802_RWTW_encodingResults_allModels_run20180912.mat'};
    % filename = {'Han_20171101_TRT_encodingResults_markersVopensim_run20180904.mat','Chips_20170915_TRT_encodingResults_markersVopensim_run20180904.mat','Lando_20170802_RWTW_encodingResults_markersVopensim_run20180904.mat'};
    filename = {'Han_20171101_TRT_encodingResults_9MuscPCs_run20180924.mat','Chips_20170915_TRT_encodingResults_9MuscPCs_run20180924.mat','Lando_20170802_RWTW_encodingResults_9MuscPCs_run20180924.mat'};
    % filename = {'Butter_20180522_TRT_encodingResults_run20180906.mat'};
    num_monks = length(filename);
    err = cell(num_monks,1);
    hyp = cell(num_monks,1);
    p_val = cell(num_monks,1);

    model_aliases = {'ext','ego','joint','musc','handelbow','ego_handelbow'};
    % model_aliases = {'joint','musc','markers','opensim_markers'};
    % model_aliases = {'opensim_ext','opensim_ego','musc','opensim_markers'};
    num_models = length(model_aliases)+1;
    model_titles = getModelTitles(model_aliases);
    model_colors = getModelColors(model_aliases);
    % colors for pm, dl conditions
    cond_colors = [0.6,0.5,0.7;...
        1,0,0];

%% Loop over all monkeys for encoder figures and errors
    for monkeynum = 1:num_monks
        clear encoderResults

        % load data
        load(fullfile(datadir,filename{monkeynum}))
    
        %% Plot PD shifts
            % get shifts from weights
            shift_tables = calculatePDShiftTables(encoderResults);
        
            mean_shifts = cell(num_models,1);
            for modelnum = 1:num_models
                mean_shifts{modelnum} = neuronAverage(shift_tables{modelnum},contains(shift_tables{modelnum}.Properties.VariableDescriptions,'meta'));
            end

            figure('defaultaxesfontsize',18)
            for modelnum = 1:num_models-1
                [~,real_shifts] = getNTidx(mean_shifts{end},'signalID',encoderResults.tunedNeurons);
                [~,model_shifts] = getNTidx(mean_shifts{modelnum},'signalID',encoderResults.tunedNeurons);
        
                subplot(1,num_models-1,modelnum)
                plot([-180 180],[0 0],'-k','linewidth',2)
                hold on
                plot([0 0],[-180 180],'-k','linewidth',2)
                plot([-180 180],[-180 180],'--k','linewidth',2)
                axis equal
                set(gca,'box','off','tickdir','out','xtick',[-180 180],'ytick',[-180 180],'xlim',[-180 180],'ylim',[-180 180])
                scatter(180/pi*real_shifts.velPD,180/pi*model_shifts.velPD,50,model_colors(modelnum,:),'filled')
        
                % labels
                xlabel 'Actual PD Shift'
                ylabel 'Modeled PD Shift'
                title({sprintf('%s model PD shift vs Actual PD shift',model_titles{modelnum});filename{monkeynum}},'interpreter','none')
            end
        
        %% Make histogram plots of PD changes
            % figure('defaultaxesfontsize',18)
            % subplot(num_models,1,1)
            % h = histogram(gca,mean_shifts{end}.velPD*180/pi,'BinWidth',10,'DisplayStyle','stair');
            % set(h,'edgecolor','k')
            % set(gca,'box','off','tickdir','out','xlim',[-180 180],'xtick',[-180 0 180],'ylim',[0 20],'ytick',[0 20])
            % for modelnum = 1:num_models-1
            %     subplot(num_models,1,modelnum+1)
            %     h = histogram(gca,mean_shifts{modelnum}.velPD*180/pi,'BinWidth',10,'DisplayStyle','stair');
            %     set(h,'edgecolor',model_colors(modelnum,:))
            %     set(gca,'box','off','tickdir','out','xlim',[-180 180],'xtick',[-180 0 180],'ylim',[0 20],'ytick',[0 20])
            % end
            % xlabel 'Change in Preferred Direction'
            % title(filename(monkeynum),'interpreter','none')
        
        %% Calculate mean error on shifts
            err{monkeynum} = calculateEncoderPDShiftErr(encoderResults);

            % % plot errors
            % figure('defaultaxesfontsize',18)
            % for modelnum = 1:num_models-1
            %     scatter(err{:,modelnum},repmat(modelnum/10,size(err,1),1),50,model_colors(modelnum,:),'filled')
            %     hold on
            %     plot(mean(err{:,modelnum}),modelnum/10,'k.','linewidth',3,'markersize',40)
            % end
            % set(gca,'tickdir','out','box','off','ytick',(1:(num_models-1))/10,'yticklabel',model_titles,'xtick',[0 1])
            % axis equal
            % axis ij
            % xlim([0 1])
            % ylim([0 num_models/10])
            % xlabel('Cosine error of model')

            % modelcompare = {'ext','ego';...
            %     'ext','musc';...
            %     'ext','handelbow';...
            %     'ego','musc';...
            %     'ego','handelbow';
            %     'musc','handelbow'};
            % tails = {'both';'right';'right';'right';'right';'right'};
            % [hyp{monkeynum},p_val{monkeynum}] = stattestPDShiftErr(err{monkeynum},modelcompare,tails,encoderResults.params.num_repeats,encoderResults.params.num_folds);
        
        %% Plot pR2s against each other
            % % setup
            % modelcompare = nchoosek(model_aliases,2);
            % figure('defaultaxesfontsize',18)
            % for i = 1:6
            %     subplot(2,3,i)
            %     plotEncoderPR2(encoderResults,modelcompare{i,1},modelcompare{i,2})
            % end
            % subplot(2,3,2)
            % title(filename{monkeynum},'interpreter','none') % centered title

        %% Tuning curve covariances
            % true_tuning_idx = contains(encoderResults.params.model_names,'S1');
            % % models_to_plot = {'ext','ego','musc','markers'};
            % models_to_plot = {'ego','ext','markers'};
            % tuning_covar = zeros(height(encoderResults.tuning_curves{1,1}),length(models_to_plot));

            % % start with just plotting out scatter plot of predicted tuning curves
            % % figure('defaultaxesfontsize',18)
            % % plot([0 0],[0 60],'-k','linewidth',3)
            % % hold on
            % % plot([0 60],[0 0],'-k','linewidth',3)
            % % plot([0 60],[0 60],'--k','linewidth',2)
            % % set(gca,'box','off','tickdir','out')
            % % axis equal
            % for neuron_idx = 1:height(encoderResults.tuning_curves{1,1})
            %     num_bins = encoderResults.params.num_tuning_bins;
            %     tuning_curve_mat = zeros(num_bins*2,length(models_to_plot)+1);
            %     for spacenum = 1:2
            %         tuning_curve_mat(num_bins*(spacenum-1)+(1:num_bins),end) = encoderResults.tuning_curves{spacenum,true_tuning_idx}(neuron_idx,:).velCurve';
            %         for modelnum = 1:length(models_to_plot)
            %             tuning_idx = contains(encoderResults.params.model_names,models_to_plot{modelnum});
            %             tuning_curve_mat(num_bins*(spacenum-1)+(1:num_bins),modelnum) = encoderResults.tuning_curves{spacenum,tuning_idx}(neuron_idx,:).velCurve';
            %             % scatter(true_curve,tuning_curve_mat(:,modelnum),[],getModelColors(models_to_plot{modelnum}),'filled')
            %         end
            %     end
            %     covar_mat = nancov(tuning_curve_mat);
            %     tuning_covar(neuron_idx,:) = covar_mat(end,1:end-1)/covar_mat(end,end);
            %     % tuning_covar(neuron_idx,:) = covar_mat(end,1:end-1);
            % end
            % % quick plot
            % figure('defaultaxesfontsize',18)
            % plot(tuning_covar','-ok','linewidth',2)
            % set(gca,'box','off','tickdir','out','xlim',[0 size(tuning_covar,2)+1])
    end
    
%% Histogram of PD shift for all monkeys
    figure('defaultaxesfontsize',18)
    for monkeynum = 1:num_monks
        % load data
        load(fullfile(datadir,filename{monkeynum}))

        shift_tables = calculatePDShiftTables(encoderResults);
        mean_shifts = cell(num_models,1);
        for modelnum = 1:num_models
            mean_shifts{modelnum} = neuronAverage(shift_tables{modelnum},contains(shift_tables{modelnum}.Properties.VariableDescriptions,'meta'));
        end

        subplot(num_monks,1,monkeynum)
        h = histogram(gca,mean_shifts{end}.velPD*180/pi,'BinWidth',10,'DisplayStyle','stair');
        set(h,'edgecolor','k')
        set(gca,'box','off','tickdir','out','xlim',[-180 180],'xtick',[-180 0 180],'ylim',[0 20],'ytick',[0 20])
        title(filename(monkeynum),'interpreter','none')
    end
    xlabel 'Change in Preferred Direction'

%% Plot error on all monkeys
    num_monks = 3;
    correction = 1/100 + 1/4;
    models_to_plot = {'ext','ego','joint','musc','handelbow','ego_handelbow'};
    % models_to_plot = model_aliases;
    % x coordinate of individual monkey bars
    monk_x = (2:3:((num_monks-1)*3+2))/10;
    % template for within monkey bars separation
    template_x = linspace(-1,1,length(models_to_plot))/10;
    model_spacing = mode(diff(template_x));

    % make plot
    figure('defaultaxesfontsize',18)
    for monkeynum = 1:num_monks
        [~,model_idx] = ismember(models_to_plot,err{monkeynum}.Properties.VariableNames);
        mean_err = mean(err{monkeynum}{:,model_idx});
        var_err = var(err{monkeynum}{:,model_idx});
        std_err_err = sqrt(correction*var_err);

        for modelnum = 1:length(models_to_plot)
            xval = monk_x(monkeynum) + template_x(modelnum);
            bar(xval,mean_err(modelnum),model_spacing,'facecolor',model_colors(model_idx(modelnum),:),'edgecolor','none')
            hold on
            plot([xval xval],[mean_err(modelnum)-std_err_err(modelnum) mean_err(modelnum)+std_err_err(modelnum)],'k','linewidth',3)
        end
        % xval = repmat(monk_x(monkeynum)+template_x,length(err{monkeynum}{:,model_idx}),1);
        % scatter(xval(:),err{monkeynum}{:,model_idx}(:),[],'k','filled')
        % plot(xval',err{monkeynum}{:,model_idx}','-k','linewidth',1)
    end
    set(gca,'tickdir','out','box','off','xtick',monk_x,...
        'xticklabel',filename,'ytick',[0 1],'ticklabelinterpreter','none')
    % axis equal
    ylim([0 0.7])
    % xlim([0 1])
    ylabel('Error of model')

%% Plot pR2 of all monkeys
    num_monks = 3;
    correction = 1/100 + 1/4;
    % models_to_plot = {'ego','ext','musc','markers'};
    models_to_plot = model_aliases;
    % x coordinate of individual monkey bars
    monk_x = (2:3:((num_monks-1)*3+2))/10;
    % template for within monkey bars separation
    template_x = linspace(-0.5,0.5,length(models_to_plot))/10;
    model_spacing = mode(diff(template_x));

    % make plot
    figure('defaultaxesfontsize',18)
    for monkeynum = 1:num_monks
        % load data
        load(fullfile(datadir,filename{monkeynum}))

        avgEval = neuronAverage(encoderResults.crossEval,contains(encoderResults.crossEval.Properties.VariableDescriptions,'meta'));

        % model_idx = find(contains(err{monkeynum}.Properties.VariableNames,models_to_plot));
        % mean_err = mean(err{monkeynum}{:,model_idx});
        % var_err = var(err{monkeynum}{:,model_idx});
        % std_err_err = sqrt(correction*var_err);

        avg_pR2 = zeros(height(avgEval),length(models_to_plot));
        for modelnum = 1:length(models_to_plot)
            xval = monk_x(monkeynum) + template_x(modelnum);
            mean_pR2 = mean(avgEval.(sprintf('glm_%s_model_eval',models_to_plot{modelnum})));
            avg_pR2(:,modelnum) = avgEval.(sprintf('glm_%s_model_eval',models_to_plot{modelnum}));
            bar(xval,mean_pR2,model_spacing,'facecolor',getModelColors(models_to_plot{modelnum}),'edgecolor','none')
            hold on
            % plot([xval xval],[mean_err(modelnum)-std_err_err(modelnum) mean_err(modelnum)+std_err_err(modelnum)],'k','linewidth',3)
        end
        xval = repmat(monk_x(monkeynum)+template_x,length(avg_pR2),1);
        scatter(xval(:),avg_pR2(:),[],'k','filled')
        plot(xval',avg_pR2','-k','linewidth',1)
    end
    set(gca,'tickdir','out','box','off','xtick',monk_x,...
        'xticklabel',filename,'ytick',[0 0.25 0.5],'ticklabelinterpreter','none')
    % axis equal
    ylim([0 0.6])
    % xlim([0 1])
    ylabel('Model pseudo-R^2')

%% Get example tuning curves for all models
    for monkeynum = 1%:num_monks
        clear encoderResults

        % load data
        load(fullfile(datadir,filename{monkeynum}))

        %% Plot out tuning curves
            % compare PM and DL tuning for each model
            for modelnum = 1:num_models
                figure('defaultaxesfontsize',18)
                % figure
                compareTuning(encoderResults.tuning_curves(:,modelnum),encoderResults.pdTables(:,modelnum),struct('which_units',find(encoderResults.isTuned),'cond_colors',cond_colors))
                % compareTuning(encoderResults.tuning_curves(:,modelnum),encoderResults.pdTables(:,modelnum),struct('which_units',find(encoderResults.isTuned),'cond_colors',cond_colors,'maxFR',1))
                title(encoderResults.params.model_names{modelnum},'interpreter','none')
            end
    end

%% Decoder crap
    datadir = '/home/raeed/Projects/limblab/data-td/FullWS/Results/Decoding';
    filename = {'Han_20160325_RWhold_decodingResults_run20180813.mat','Chips_20151211_RW_decodingResults_run20180813.mat'};
    num_monks = length(filename);
    barwidth = 0.4;
    markerstyle = '^o';
    barfig = figure('defaultaxesfontsize',18);
    scatfig = figure('defaultaxesfontsize',18);
    for monkeynum = 1:num_monks
        %% load data
        load(fullfile(datadir,filename{monkeynum}))

        %% make decoder performance scatter plots
        x_offset = monkeynum-1;
        % first monkey
        figure(barfig)
        bar([1 3 2 4]*0.20+x_offset,mean([decoderResults.hand_decoder_vaf decoderResults.neur_decoder_vaf]),barwidth,'facecolor',[0.5 0.5 0.5],'edgecolor','none')
        hold on
        plot([1 2]*0.20+x_offset,[decoderResults.hand_decoder_vaf(:,1) decoderResults.neur_decoder_vaf(:,1)]','-k','linewidth',1)
        plot([3 4]*0.20+x_offset,[decoderResults.hand_decoder_vaf(:,2) decoderResults.neur_decoder_vaf(:,2)]','-k','linewidth',1)
        plot([1 3 2 4]*0.20+x_offset, [decoderResults.hand_decoder_vaf decoderResults.neur_decoder_vaf]','.k','markersize',30)

        figure(scatfig)
        subplot(1,2,1)
        scatter(decoderResults.hand_decoder_vaf(:,1),decoderResults.neur_decoder_vaf(:,1),markerstyle(monkeynum),'filled')
        hold on
        plot([0 1],[0 1],'--k','linewidth',2)

        subplot(1,2,2)
        scatter(decoderResults.hand_decoder_vaf(:,2),decoderResults.neur_decoder_vaf(:,2),markerstyle(monkeynum),'filled')
        hold on
        plot([0 1],[0 1],'--k','linewidth',2)
    end
    figure(barfig)
    xtick = [(1:4)*0.20 1+(1:4)*0.20];
    xticklabel = repmat({'Hand-only pos','Hand+Neuron pos','Hand vel','Hand+Neuron vel'},1,2);
    set(gca,'box','off','tickdir','out','xtick',xtick,...
        'xticklabel',xticklabel,...
        'xlim',[0 num_monks],'ylim',[0 1])
    ylabel 'Fraction VAF'
    xlabel 'Model'
    title([{'Decoding performance'};filename'],'interpreter','none')

    figure(scatfig)
    subplot(1,2,1)
    axis equal
    subplot(1,2,2)
    axis equal

%% Extra stuff/in progress...
    %% Example predictions
        td_tuning = encoderResults.td_tuning{2};
        td_tuning = smoothSignals(td_tuning,struct('signals','S1_FR','kernel_SD',0.1));
        trial_to_plot = randperm(length(td_tuning),5);
        num_neurons = length(td_tuning(1).S1_unit_guide);
        for neuron_idx = 23
            h = figure('defaultaxesfontsize',18);
            trial_to_plot = randperm(length(td_tuning),5);
            temp_vel = get_vars(td_tuning(trial_to_plot),{'vel',1:2});
            temp_spikes = get_vars(td_tuning(trial_to_plot),{'S1_FR',neuron_idx});
            temp_pred_ext = get_vars(td_tuning(trial_to_plot),{'glm_ext_model',neuron_idx});
            temp_pred_ego = get_vars(td_tuning(trial_to_plot),{'glm_ego_model',neuron_idx});
            temp_pred_musc = get_vars(td_tuning(trial_to_plot),{'glm_musc_model',neuron_idx});
            temp_pred_markers = get_vars(td_tuning(trial_to_plot),{'glm_markers_model',neuron_idx});

            clf
            % ax1 = subplot(2,1,1);
            % plot(temp_vel(:,1),'b','linewidth',2)
            % hold on
            % plot(temp_vel(:,2),'g','linewidth',2)
            % set(gca,'box','off','tickdir','out')
            % 
            % ax2 = subplot(2,1,2);
            plot(temp_spikes,'k','linewidth',2)
            hold on
            plot(temp_pred_ext,'color',model_colors(contains(model_aliases,'ext'),:),'linewidth',2)
            plot(temp_pred_ego,'color',model_colors(contains(model_aliases,'ego'),:),'linewidth',2)
            plot(temp_pred_musc,'color',model_colors(contains(model_aliases,'musc'),:),'linewidth',2)
            % plot(temp_pred_markers,'color',model_colors(contains(model_aliases,'markers'),:),'linewidth',2)
            % title(sprintf('Hand-based pR^2: %f, Musc-based pR^2: %f',av_pR2_ext(neuron_idx),av_pR2_musc(neuron_idx)))
            set(gca,'box','off','tickdir','out')
            % linkaxes([ax1 ax2],'x')
            waitfor(h)
        end
        clearvars neuron_idx temp_* ax1 ax2
    
    %% Plot handle positions
        if verbose
            figure('defaultaxesfontsize',18)
            pos_dl = cat(1,results.td_test{2}.pos);
            plot(pos_dl(:,1),pos_dl(:,2),'r')
            hold on
            pos_pm = cat(1,results.td_test{1}.pos);
            plot(pos_pm(:,1),pos_pm(:,2),'b')
            axis equal
    
            % clean up
            clearvars pos_*
        end
    
    %% Plot tuning weight clouds
        % tuningHull = getTuningHull(results.tuningTable);
        % loop over each unit in one workspace
        % n_rows = ceil(sqrt(height(signalIDs)+1));
        % cloud_fig = figure('defaultaxesfontsize',18);
        % surf_fig = figure('defaultaxesfontsize',18);
        % neuron_idx = getNTidx(pdTables{1,4},'signalID',[95 2]);
        for neuron_idx = 1:length(encoderResults.isTuned)
            % close_fig = figure('defaultaxesfontsize',18);
    
            % figure(cloud_fig)
            % clf
            % plotMWTuningCloud(tuningHull,neuron_idx)
    
            surf_fig = figure('defaultaxesfontsize',18);
            clf
            plotMWTuningSurfaces(encoderResults.td_tuning,pdTables,neuron_idx,model_aliases)
    
            waitfor(surf_fig)
        end
