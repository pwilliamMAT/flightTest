function g = helperLLGeometry(p,tx,rx,R,columns,available,maxCondition,limit)
%HELPERLLGEOMETRY Local range-only information, with rank honestly retained.
% Each row of H describes the direction in which one excess range changes.
% Whitening accounts for measurement covariance. SVD reveals missing spatial
% directions without turning an unobservable direction into false certainty.
n = size(p,1);
j = size(tx,1);
d = numel(columns);
assert(isequal(size(R),[j j]),"Range covariance must match transmitter count.");
g.rho = zeros(n,j);
g.H = zeros(n,j,3);
rr = vecnorm(p-rx,2,2);
for k = 1:j
    rt = vecnorm(p-tx(k,:),2,2);
    assert(all(rt>0) && all(rr>0),"Target must not coincide with a site.");
    g.rho(:,k) = rt + rr - norm(tx(k,:)-rx);
    g.H(:,k,:) = reshape((p-tx(k,:))./rt + (p-rx)./rr,n,1,3);
end
g.rank = zeros(n,1);
g.singularValues = zeros(n,d);
g.condition = inf(n,1);
g.covariance = inf(d,d,n);
g.horizontalRMS = inf(n,1);
g.verticalRMS = inf(n,1);
if d == 2
    g.verticalRMS(:) = 0;
end
g.totalRMS = inf(n,1);
g.geometryRMS = inf(n,1);
g.useful = false(n,1);
for q = 1:n
    use = find(available(q,:));
    if isempty(use)
        continue
    end
    H = reshape(g.H(q,use,columns),numel(use),d);
    L = chol(R(use,use),"lower");
    [~,S,V] = svd(L\H,"econ");
    s = diag(S);
    tol = max(size(H))*eps(max(s));
    r = sum(s>tol);
    g.rank(q) = r;
    g.singularValues(q,1:numel(s)) = s;
    if r < d
        continue % Never report pseudoinverse confidence for full position.
    end
    g.condition(q) = s(1)/s(end);
    B = V./s';
    C = B*B'; % Equivalent to (H'/R*H)^-1, without explicit inversion.
    g.covariance(:,:,q) = C;
    g.horizontalRMS(q) = sqrt(sum(diag(C(1:2,1:2))));
    g.verticalRMS(q) = 0; % Local receiver-frame Up is fixed in the 2-D case.
    if d == 3
        g.verticalRMS(q) = sqrt(C(3,3));
    end
    g.totalRMS(q) = sqrt(trace(C));
    su = svd(H,"econ");
    g.geometryRMS(q) = sqrt(sum(1./su.^2));
    g.useful(q) = g.condition(q)<=maxCondition && g.totalRMS(q)<=limit;
end
end
