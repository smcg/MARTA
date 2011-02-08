function idx = RandAdjScreen(idx, tokenlist)
%RANDADJSCREEN  - PARSEEXPFILE randomizer that screens for adjacent identical tokens
%
%	usage:  idx = RandAdjScreen(idx, tokenlist)
%
% this procedure is a replacement for the default RANDOMIZER that produces a randomized
% permutation IDX of the tokens in TOKENLIST that screens for adjacent identical tokens
%
% should be passed as rand="RandAdjScreen" in PARSEEXPFILE <DEFBLOCK> declarations
%
% screening is performed on contents of PROMPT field

% mkt 07/09

if nargin < 2,
	eval('help RandAdjScreen');
	return;
end;

prompts = {tokenlist.PROMPT}';
idx = idx(:);

n = 0;
tries = 0;
idx = idx(randperm(numel(idx))');

while 1,
	s = char(prompts(idx));
	k = find(all(0 == diff(double(s)),2)) + 1;
	if isempty(k), break; end;
	q = setdiff([1:length(idx)],k)';
	if mod(n,2),
		k = [k;q];
	else,
		k = [q;k];
	end;
	idx = idx(k);
	n = n + 1;
	if n > 10,			% try again with new permutation
		tries = tries + 1;
		if tries > 10,
			fprintf('\nunable to find permutation avoiding adjacency\n');
			break;
		end;
		idx = idx(randperm(numel(idx))');
		n = 0;
	end;
end;
