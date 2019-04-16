%%
fileAddress='exam.tex';
fileID=fopen(fileAddress,'r','n','UTF-8');
line = fgetl(fileID);
lines = cell(0,1);
while ischar(line)
    lines{end+1,1} = line;
    line = fgetl(fileID);
end
fclose(fileID);

%Preamble and Ending
preamble=lines(1:find(strcmp(lines,'\begin{questions}')));
ending=lines(find(strcmp(lines,'\end{questions}')):end);

%mainlines=lines(find(strcmp(lines,'\begin{questions}')):find(strcmp(lines,'\end{questions}')));

%Getting Problems Text
begProb=find(cellfun(@(x)(~isempty(strfind(x,'\question'))),lines));
begProb=begProb(2:end);
nProbs=length(begProb);
begProb(end+1)=find(strcmp(lines,'\end{questions}'));
probtxt=cell(nProbs,1);
for i=1:nProbs
    probtxt{i}=lines(begProb(i):begProb(i+1)-1);
end

%Getting primary and alternative problems
nPrim=nProbs-length(find(cellfun(@(x)(~isempty(strfind(x,'\questionalt'))),lines)));
isPrim=zeros(nProbs,1);
for i=1:nProbs
    isPrim(i)=isempty(strfind(probtxt{i}{1},'\questionalt'));
end

j=0;
nAlt=zeros(nPrim,1);
for i=1:nProbs
    if isPrim(i)
%         if j>0 nAlt(j)=k;
        j=j+1;
        nAlt(j)=1;
        altProb(j,1)=i;
    else
        nAlt(j)=nAlt(j)+1;
        k=nAlt(j);
        altProb(j,k)=i;
    end
end
% begSec=strfind(lines,'\section');
% begSec= find(not(cellfun('isempty', begSec)));
% nSec=length(begSec);
% begSec(end+1)=find(strcmp(lines,'\end{questions}'));
% probSec=zeros(nProbs,1);
% for i=1:nSec
%     probSec(find((begProb>begSec(i))&(begProb<begSec(i+1))))=i;
% end


%Split problem text to question and choices
nChoices=zeros(nProbs,1);
corrChoice=zeros(nProbs,1);
quest=cell(nProbs,1);
for i=1:nProbs
    choicesBeg=find(not(cellfun('isempty', strfind(probtxt{i},'\begin{choices}'))&cellfun('isempty', strfind(probtxt{i},'\begin{oneparchoices}'))));
    choicesEnd=find(not(cellfun('isempty', strfind(probtxt{i},'\end{choices}'))&cellfun('isempty', strfind(probtxt{i},'\end{oneparchoices}'))));
    quest{i}=probtxt{i}(1:choicesBeg);
    questEnding{i}=probtxt{i}(choicesEnd:end);
    begChoiceLine=find(not(cellfun('isempty', strfind(probtxt{i},'\choice'))&cellfun('isempty', strfind(probtxt{i},'\CorrectChoice'))));
    nChoices(i)=length(begChoiceLine);
    begChoiceLine(end+1)=choicesEnd;
    corrline=find(not(cellfun('isempty', strfind(probtxt{i},'\CorrectChoice'))));
    if not(isempty(corrline))
        corrChoice(i)=find(begChoiceLine==corrline);
    end
    for j=1:nChoices(i)
        choice{i,j}=probtxt{i}(begChoiceLine(j):begChoiceLine(j+1)-1);
    end
end


%% Generate Permutations

nSets=80;
%codes=floor(1+9*rand(nSets,10))
codes=(1:nSets)';

permMat=zeros(nSets,nPrim,nPrim);
probPerm=zeros(nSets,nPrim);
probAlt=zeros(nSets,nPrim);
probPermInv=zeros(nSets,nPrim);
choiceShift=zeros(nSets,nPrim);
probList=zeros(nSets,nPrim);
for k=codes'
    rng(k);
    %Generate permutation of problems for each set
    I=eye(nPrim);
    permMat(k,:,:)=I(randperm(nPrim),:);
    probPerm(k,:)=squeeze(permMat(k,:,:))*(1:nPrim)';
    probPermInv(k,:)=squeeze(permMat(k,:,:))\(1:nPrim)';
    %Generate Shift of choices
    for j=1:nPrim
        probAlt(k,j)=randi(nAlt(probPerm(k,j)));
        probList(k,j)=altProb(probPerm(k,j),probAlt(k,j));
    end
    for j=1:nPrim
        choiceShift(k,j)=randi(nChoices(probList(k,j)));
    end
end

%% Generate Answer Key

%Create Problem Lists
A=[codes,probList];
%Create Permutation sheet
B=[codes,probPerm];
%Create Inverse Permutation sheet
C=[codes,probPermInv];
%Create choices shift sheet
D=[codes,choiceShift];
%Create number of choices sheet
E=zeros(nSets,nProbs);
for k=codes'
    for j=1:nPrim
        E(k,j)=nChoices(probList(k,j));
    end
end
E=[codes,E];
%Create correct choices sheet
F=zeros(nSets,nProbs);
for k=codes'
    for i=1:nPrim
        F(k,i)=1+mod(choiceShift(k,i),nChoices(probPerm(k,i)));
    end
end
F=[codes,F];
%Write to File
xlswrite('key.xlsx',A,'ProbList');
xlswrite('key.xlsx',B,'Perm');
xlswrite('key.xlsx',C,'InvPerm');
xlswrite('key.xlsx',D,'ChoiceShift');
xlswrite('key.xlsx',E,'NumChoice');
xlswrite('key.xlsx',F,'CorrectChoice');

%% Generate Problem Sets

%Create Problem Sets as Cell array
probSet=cell(nSets,1);
for k=codes'
    probSet{k}=preamble;
    probSet{k}{1}=['\newcommand\code{',num2str(k),'}'];
    for j=1:nPrim
        probSet{k}=[probSet{k};quest{probList(k,j)}];
        for l=1:nChoices(probList(k,j))
            probSet{k}=[probSet{k};choice{probList(k,j),1+mod(l-choiceShift(k,j)-1,nChoices(probList(k,j)))}];
        end
        probSet{k}=[probSet{k};questEnding{probList(k,j)}];        
    end
    probSet{k}=[probSet{k};ending];        
end

%Create Problem sets as text
probSetText=cell(nSets,1);
for k=codes'
    probSetText{k}= probSet{k}{1};
    for i=2:length(probSet{k})
        probSetText{k}=[probSetText{k},sprintf('\n'),probSet{k}{i}];
    end
end


%Write Problem Set Text to File
for k=codes'
    fileAddress=['ProblemSets\exam',num2str(k),'.tex'];
    fileID=fopen(fileAddress,'w','n','UTF-8');
%    fprintf(fileID,probSetText{k});
    fprintf(fileID,'%s',probSetText{k});
    fclose(fileID);
end
fclose all;

%% Typesetting the Problem Sets

fileAddress='ProblemSets\batchfile.bat';
fileID=fopen(fileAddress,'w');

batchText='';
for k=codes'
    batchText=[batchText,sprintf('\n'),'xelatex exam',num2str(k),'.tex'];
%    batchText=[batchText,sprintf('\n'),'xelatex exam',num2str(k),'.tex'];
end
fprintf(fileID,'%s',batchText);
fclose(fileID);
cd('ProblemSets');
system('batchfile.bat');
cd ..;
