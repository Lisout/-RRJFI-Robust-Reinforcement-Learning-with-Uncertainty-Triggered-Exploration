function results = runAllTests
%RUNALLTESTS Execute the RRJFI MATLAB verification suite.

testFolder = fileparts(mfilename('fullpath'));
projectRoot = fileparts(testFolder);
originalPath = path;
pathCleanup = onCleanup(@() path(originalPath));
addpath(fullfile(projectRoot, '01_core'));
addpath(fullfile(projectRoot, '02_training'));
addpath(testFolder);
suite = testsuite(testFolder, 'IncludeSubfolders', true);
results = run(suite);
assertSuccess(results);
end
