function [ y_fit, m, phi, theta, d ] = my_arima( y, max_phi, max_theta, max_d, current_d )
% augmented Dickey-Fuller test URT
h=adftest(y);
if(h || current_d>=max_d ) % do not contain UR, no need difference, or max allowed differencing exceeded
    d=current_d; % return d
    if exist('parcorr', 'file')
        [acf, lags, bounds]=autocorr(y, min(length(y)-1, 10)); % acf
        [PARCOR, lags, pbounds]=parcorr(trn_speed, min(length(y)-1, 10)); % pacf
        max_theta=min( [max_theta, find(acf>bounds(1), 1, 'last')-1, find(acf<bounds(2), 1, 'last')-1] );
        max_phi=min( [max_phi, find(PARCOR>pbounds(1), 1, 'last')-1, find(PARCOR<pbounds(2), 1, 'last')-1] );
        max_theta=max([max_theta, 1]);
        max_phi=max([max_phi, 1]);
    else
        [acf]=acovf(y, min(length(y)-1, 10)); % acf
        acf=acf/acf(1);%normalized
        bounds=[ 1.96/sqrt(min(length(y)-1, 10)) , -1.96/sqrt(min(length(y)-1, 10)) ];
        [PARCOR, sig, cil, ciu] = pacf(trn_speed', min(length(trn_speed)-1, 10)); % pacf
        max_theta=min( [max_theta, find(acf>bounds(1), 1, 'last')-1, find(acf<bounds(2), 1, 'last')-1] );
        max_phi=min( [max_phi, find(PARCOR>cil(1), 1, 'last')-1, find(PARCOR<ciu(1), 1, 'last')-1] );
        max_theta=max([max_theta, 1]);
        max_phi=max([max_phi, 1]);
    end
    
    z=iddata(y);
    aic_grid=inf(max_phi, max_theta);
    for phi=0:max_phi
        for theta=0:max_theta
            if phi+theta==0
                continue;
            else
                m=armax(z, 'na', phi, 'nc', theta);
                aic_grid(phi+1, theta+1)=aic(m);
            end
        end
    end
    min_aic=min(min(aic_grid));
    [best_phi, best_theta]=find(aic_grid==min_aic);
    phi=best_phi(1)-1;
    theta=best_theta(1)-1;
    m=armax(z, 'na', best_phi, 'nc', best_theta);
    
    y_fit=predict(m, y);
    y_fit=y_fit{:};
    %     for i=d:-1:1 % need cumsum
    %        y_fit=cumsum([y(1);y_fit]);
    %     end
else % contain UR, need difference
    if(current_d<max_d)
        d=current_d+1;
        dy=diff(y);
        [ y_fit, m, phi, theta, d ]=my_arima(dy, max_phi, max_theta, max_d, d);
        y_fit=cumsum([y(1);y_fit]);
    end
end



% plot(y, '.-k');
% hold on
% plot(y_fit, '.-b');
% hold off


end

