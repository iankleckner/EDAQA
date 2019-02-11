function [EDA_datum_valid, data_EDA_uS_filtered] = run_automated_EDAQA( ...
    data_EDA_uS, data_time_sec, data_temperature_C, ... % Input data
    QA_filter_window_EDA_sec, ... % Filter 
    QA_EDA_floor, QA_EDA_ceiling, ... % Rule 1
    QA_EDA_max_slope_uS_per_sec, ... % Rule 2
    QA_temperature_C_min, QA_temperature_C_max, ... % Rule 3
    QA_radius_to_spread_invalid_datum_sec ) % Rule 4
%RUN_AUTOMATED_EDAQA Runs automated EDA quality assessment procedure from Kleckner, et al.
%   Four simple rules for determining invalid data:
%   1. EDA is out of valid range (e.g., not within 0.05-60 uS)
%   2. EDA changes too quickly (e.g., faster than +-10 ?S/sec)
%   3. Temperature is out of range (e.g., not within 30-40ºC)
%   4. EDA data surrounding (e.g., within 5 sec of) invalid portions from rules 1-3 are also invalid
%
%   INPUT VARIABLES
%       data_EDA_uS - 1D vector where each element is EDA in microsiemens
%       data_time_sec - 1D vector where each element is time in seconds
%       data_temperature_C - 1D vector where each element is temperature in
%           Celcius ( if no temperature data availble, set as empty matrix, [] ).
%
%       QA_filter_window_EDA_sec - Filter window length in sec (e.g., 2),
%       use NaN to disable filter
%
%       QA_EDA_floor - Rule 1, Lower limit of EDA data in uS (e.g., 0.05)
%       QA_EDA_ceiling - Rule 1, Upper limit of EDA data in uS (e.g., 60)
%       QA_EDA_max_slope_uS_per_sec - Rule 2, Maximum slope of EDA dta in uS/sec (e.g., 10)
%       QA_temperature_C_min - Rule 3, Minimum temperature in Celcius (e.g., 30)
%       QA_temperature_C_max - Rule 3, Maximum temperature in Celcius (e.g., 40)
%       QA_radius_to_spread_invalid_datum_sec - Rule 4, Transition radius for artifacts in sec (e.g., 5)
%
%   OUTPUT VARIABLES
%       EDA_datum_invalid - 1D vector where each element is either 1=Datum invalid or 0=Datum valid
%       data_EDA_uS_filtered - 1D vector where each element is EDA in microsiemens after filtering
%
%   AUTHORS
%       Ian Kleckner, PhD
%       University of Rochester Medical Center (Rochester, NY, USA)
%       ian.kleckner at gmail.com
%
%       With Matthew Goodwin, PhD
%       Northeastern University (Boston, MA, USA)
%
%   CHANGELOG
%       2016/12/18 Put in function form for publication
%       2019/02/11 Filter is optional (use NaN) to disable it

    %% Check that inputs are valid
    
    % Input data must be same length
    if( length(data_EDA_uS) ~= length(data_time_sec) || ...
        length(data_EDA_uS) ~= length(data_temperature_C) || ...
        length(data_time_sec) ~= length(data_temperature_C) )
        fprintf('\n');
        error('Input data must all be the same length. If you do not have temperature data, use []');
    end
    
    % EDA floor must be less than EDA ceiling
    if( QA_EDA_floor >= QA_EDA_ceiling )
        fprintf('\n');
        error('EDA floor must be less than EDA ceiling');
    end
    
    % If no temperature data provided, then set it to between temperature
    % min and max so it will never indicate data as "invalid"
    if( isempty(data_temperature_C) )
        QA_temperature_C_min = 0;
        QA_temperature_C_max = 1;
        data_temperature_C = 0.5 * ones(1,length(data_EDA_uS));
        
    else
        % Temperature floor must be less than temperature ceiling
        if( QA_temperature_C_min >= QA_temperature_C_max )
            fprintf('\n');
            error('Temperature min must be less than temperature max');
        end
    end

    %% Process data (filter, checks, etc.)
    
    % Determine sampling period
    sampling_period_EDA = data_time_sec(2) - data_time_sec(1);
    
    %----------------------------------------------------------------------
    % Look for NaN values in EDA data, and replace them with mean of the
    % surrounding values
    k_NaN_array = find( isnan(data_EDA_uS) );

    for k = 1:length(k_NaN_array)
        k_NaN = k_NaN_array(k);

        data_EDA_uS(k_NaN) = mean([data_EDA_uS(k_NaN-1), data_EDA_uS(k_NaN+1)]);
        fprintf('\n** EDA data: Replacing found NaN number %d with %f', k, data_EDA_uS(k_NaN));
    end
    
    %----------------------------------------------------------------------
    % Look for NaN values in temperature data, and replace them with mean of the
    % surrounding values
    k_NaN_array = find( isnan(data_temperature_C) );

    for k = 1:length(k_NaN_array)
        k_NaN = k_NaN_array(k);

        data_temperature_C(k_NaN) = mean([data_temperature_C(k_NaN-1), data_temperature_C(k_NaN+1)]);
        fprintf('\n** Temperature data: Replacing found NaN number %d with %f', k, data_temperature_C(k_NaN));
    end

    if( ~isnan(QA_filter_window_EDA_sec) )
        try
        % Filter with small window for quality assessment            
        windowSize = QA_filter_window_EDA_sec / sampling_period_EDA;    
        b = (1/windowSize)*ones(1,windowSize);
        a = 1;
        data_EDA_uS_filtered  = filtfilt(b, a, data_EDA_uS);

        % Repeat filter for QA of temperature
        windowSize = QA_filter_window_EDA_sec / sampling_period_EDA;    
        b = (1/windowSize)*ones(1,windowSize);
        a = 1;
        data_temperature_C_filtered  = filtfilt(b, a, data_temperature_C);

        % If temperature data are all NaN
        if( sum(~isnan(data_temperature_C_filtered)) == 0 )
            fprintf('\n\t** ');
            warning('Temperature data could not be filtered for some reason. Using unfiltered temperature data for QA');
            data_temperature_C_filtered = data_temperature_C;

            fprintf('\n\tNumber of NaNs in raw temperature data: %d (%0.0f%%)', sum(isnan(data_temperature_C)),  100*sum(isnan(data_temperature_C))/length(data_temperature_C));
        end

        catch error_message
            % There was an error processing. Skip this participant
            fprintf('\n** ERROR: %s\n%s', error_message.message, error_message.identifier);
            return;
        end
    else
        % Use UNFILTERED data
        data_EDA_uS_filtered        = data_EDA_uS;
        data_temperature_C_filtered = data_temperature_C;
    end

    %% Quality assessment of EDA data
    
    % Calculate instantaneous slope for Rule 2
    data_Q_EDA_uS_per_sec_filtered_QA = [0; diff(data_EDA_uS_filtered) ./ sampling_period_EDA];

    % Implementation of EDA rules 1, 2, and 3
    EDA_datum_invalid_123 = or( (data_EDA_uS_filtered < QA_EDA_floor), ...
                              or( (data_EDA_uS_filtered > QA_EDA_ceiling), ...
                              or( (abs(data_Q_EDA_uS_per_sec_filtered_QA) > QA_EDA_max_slope_uS_per_sec), ...
                              or( (data_temperature_C_filtered < QA_temperature_C_min), ...
                                  (data_temperature_C_filtered > QA_temperature_C_max) ) ) ) );

    % Determine number of data points to spread for Rule 4
    QA_radius_to_spread_invalid_datum_Ndata = QA_radius_to_spread_invalid_datum_sec / sampling_period_EDA;    
    
    % Implementation of EDA rule 4
    EDA_datum_invalid = EDA_datum_invalid_123;
    for d = 1:length(EDA_datum_invalid_123)

        % Check if the data point is invalid
        if( EDA_datum_invalid_123(d) )

            % Propagate this to the end of the array of the point radius,
            % whatever is smaller

            % Spread to right
            if( d+QA_radius_to_spread_invalid_datum_Ndata-1 > length(EDA_datum_invalid_123) )
                EDA_datum_invalid(d : end) = 1;
            else
                EDA_datum_invalid(d : d+QA_radius_to_spread_invalid_datum_Ndata-1) = 1;
            end

            % Spread to left
            if( d-QA_radius_to_spread_invalid_datum_Ndata+1 < 1 )
                EDA_datum_invalid(1 : d) = 1;
            else
                EDA_datum_invalid(d-QA_radius_to_spread_invalid_datum_Ndata+1 : d) = 1;
            end
        end
    end

EDA_datum_valid = ~EDA_datum_invalid;
end