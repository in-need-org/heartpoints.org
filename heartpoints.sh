#!/usr/bin/env bash

heartpoints() { local command=$1; local remainingArgs="${@:2}"
    if string_is_empty "${command}"; then
        heartpoints_help
    else
        local localFunctionName="heartpoints_${command}"
        if function_exists "${localFunctionName}"; then
            $localFunctionName "${@:2}"
        else
            if function_exists $command; then
                $command "${@:2}"
            else
                heartpoints_help
                error_and_exit "Command not found"
            fi
        fi
    fi
}

allFunctionNames() {
    declare -F | awk '{print $NF}' | sort | uniq | grep -v "^_" 
}

function_exists() { local functionName=$1
    type -t $functionName > /dev/null 2>&1
}

heartpoints_help() {
    echo ""
    echo "Usage: heartpoints.sh [command]"
    echo ""
    echo "Commands:"
    echo ""
    functionNamesAndDescriptions
}

error_and_exit() { local errorMessage=$1
    echo $errorMessage
    exit 1
}

functionNamesAndDescriptions() {
    declare -a functionNames=($(publicFunctionNames))
    for fullFunctionName in "${functionNames[@]}"
    do
        local possibleHelp=""
        local possibleHelpFunctionName="${fullFunctionName}_help"
        if function_exists "${possibleHelpFunctionName}"; then
            possibleHelp=" - $(${possibleHelpFunctionName})"
        fi
        local niceFunctionName="$(string_everythingAfterChar "${fullFunctionName}" "_")"
        echo "$(fixStringWidth "${niceFunctionName}" 30)$(fixStringWidth "${possibleHelp}" 80)"
    done
}

publicFunctionNames() {
    allFunctionNames | grep "heartpoints_" | grep -v "_help"
}

stringLength() { local stringInQuestion=$1
    echo ${#stringInQuestion}
}

fixStringWidth() { local originalString=$1; local fixedWidth=$2
    local limitedString="$(string_firstNChars "${originalString}" $fixedWidth)"
    local limitedStringLength="$(stringLength "${limitedString}")"
    local spacesNeeded=$(expr $fixedWidth - $limitedStringLength)
    local spaces="$(padString " " $spacesNeeded)"
    echo "${limitedString}${spaces}"
}

padString() { local stringToPad=$1; local numTimes=$2
    local printFCommand="printf '${stringToPad}%.0s' {0..${numTimes}}"
    eval $printFCommand
}

heartpoints_localDev_help() { echo "DEPRECATED"; }
heartpoints_localDev() {
    heartpoints_serverDev
    error_and_exit "localDev is deprecated. For server side development, use ./hp serverDev or for client side development use ./hp clientDev"
}

string_toLower() { local stringToConvertToAllLowercase=$1
    echo "$stringToConvertToAllLowercase" | tr '[:upper:]' '[:lower:]'
}

string_firstNChars() { local sourceString=$1; local n=$2
    echo "${sourceString}" | cut -c 1-$n
}

string_everythingAfterChar() { local sourceString=$1; local delimitingCharacter=$2;
    echo "${sourceString}" | cut -d "${delimitingCharacter}" -f 2- -
}

string_everythingBeforeChar() { local sourceString=$1; local delimitingCharacter=$2;
    cut -d "${delimitingCharacter}" -f 1 <<< "$sourceString"
}

git_safeBranchNameFromIssueDescription() { local issueDescription=$1
    local lowercased="$(string_toLower "${issueDescription}")"
    local maxLength="50"
    local trimmed="$(string_firstNChars "${lowercased}" $maxLength)"
    local spacesReplacedWithDashes="${trimmed// /-}"
    local withoutQuotes="${spacesReplacedWithDashes//\"/}"
    local withoutPoundSignOrLeadingSpace="$(string_everythingAfterChar "${withoutQuotes}" "#")"
    echo $withoutPoundSignOrLeadingSpace
}

get_pullLatestForCurrentBranch() {
    heartpoints_ensureCommitIsAppropriate
    git pull --rebase origin "$(git_currentBranchName)"
}

git_issueDescriptionForIssueId() { local issueId=$1
    echo "$(heartpoints_hub issue | grep "#${issueId} ")"
}

git_safeBranchNameForIssueId() { local issueId=$1
    echo "$(git_safeBranchNameFromIssueDescription "$(git_issueDescriptionForIssueId $issueId)")"
}

git_currentBranchName() { 
    git rev-parse --abbrev-ref HEAD
}

heartpoints_c_help() { echo "Alias for commitUsingIssueDescription"; }
heartpoints_c() {
    heartpoints_commitUsingIssueDescription
}

hub_issueIdOfCurrentBranch() {
    string_everythingBeforeChar "$(git_currentBranchName)" "-"
}

hub_descriptionOfCurrentBranchIssue() {
    git_issueDescriptionForIssueId "$(hub_issueIdOfCurrentBranch)"
}

hub_defaultCommitMessageForCurrentBranch() {
    echo "fixes $(trimLeadingWhitespace "$(hub_descriptionOfCurrentBranchIssue)")"
}

heartpoints_addCommitPushAndPullRequest_help() { echo "adds changes, commits with default description, pushes to remote branch, creates pull request"; }
heartpoints_addCommitPushAndPullRequest() {
    heartpoints_c
    git push origin head
    heartpoints_hub pull-request
}

heartpoints_createPullRequest_help() { echo "create pull request using commit message"; }
heartpoints_createPullRequest() {
    heartpoints_hub pull-request -m "$(hub_defaultCommitMessageForCurrentBranch)"
}

trimAllWhitespace() { local stringToTrim=$1
    echo "${stringToTrim}" | tr -d '[:space:]'
}

trimLeadingWhitespace() { local stringToTrim=$1
    echo "${stringToTrim}" | sed -e 's/^[[:space:]]*//'
}

heartpoints_commitUsingIssueDescription() {
    git add -A
    git commit -m "$(hub_defaultCommitMessageForCurrentBranch)"
}

heartpoints_createIssueAndBranch_help() { echo "<issueDescription> - creates branch and issue using provided description, checks out branch"; }
heartpoints_createIssueAndBranch() { local issueDescription=$1
    local issueURL=$(heartpoints_hub issue create -m "${issueDescription}")
    local issueId="$(everythingAfterLastSlash "${issueURL}")"
    echo
    echo "Created issue: ${issueURL}"
    echo
    heartpoints_branch "${issueId}"
}

everythingAfterLastSlash() { local stringWithSlashes=$1
    echo ${stringWithSlashes##*/}
}

heartpoints_branch_help() { echo "lists issues, unless issueId provided, then creates branch"; }
heartpoints_branch() { local issueId=$1
    if string_is_empty "$issueId"; then
        heartpoints_hub issue
        echo "Run again with issue number to create and switch to appropriately named branch"
    else
        heartpoints_hub_install
        if strings_are_not_equal "$(git_currentBranchName)" "master"; then
            echo "Error: you are not in the 'master' branch, you are instead in the '$(git_currentBranchName)' branch."
            echo "Before using this command, first switch to master using 'git checkout master'"
            echo "After that, make sure you have the latest from the remote master, by running 'git pull origin master'"
            echo "With that out of the way, you may run this command to create a new branch"
            error_and_exit " Please try again"
        fi
        local newBranchToPossiblyCreate="$(git_safeBranchNameForIssueId "${issueId}")"
        git checkout -b "${newBranchToPossiblyCreate}"
        echo
        echo "created / switched to branch '${newBranchToPossiblyCreate}'"
        echo
        echo "Use 'git add -A' and 'git commit -m ' to commit to this branch"
        echo "Use 'git push origin head' to push this branch to the remote repository"
        echo "Use 'hp hub pull-request' to create a new pull request from your remote branch to remote master"
        echo "From there, you will receive a URL where you can:"
        echo " - view your change"
        echo " - request reviewers"
        echo " - View the status of automated tests"
        echo
    fi
}

heartpoints_checkoutPullRequest_help() { echo "given pull request number / branch name, check out locally"; }
heartpoints_checkoutPullRequest() { local pullRequestIdOrBranchName=$1
    heartpoints_hub pr checkout "${pullRequestIdOrBranchName}"
}

heartpoints_serverDev_help(){ echo "run dev web server locally"; }
heartpoints_serverDev(){
    heartpoints_prepareForRun
    heartpoints_runServer
}

heartpoints_clientDev_help() { echo "run front-end web server with hot reloading"; }
heartpoints_clientDev(){
    heartpoints_yarn install
    heartpoints_runWebPackDevServer
}

heartpoints_hub_help() { echo "use the github cli"; }
heartpoints_hub() { local args=$@
    heartpoints_hub_install
    hub "$@"
}

heartpoints_hub_install() {
    brew_install hub
}

brew_install() { local packageName=$1
    if command_does_not_exist "${packageName}"; then
        heartpoints_brew install "$packageName"
    fi
}

heartpoints_prepareForRun() { 
    heartpoints_yarn install
    heartpoints_yarn webpack --verbose
    if file_does_not_exist "dist/bundle.js"; then
        echo "dist/bundle.js not found. was webpack successful?"
        exit 1
    fi
}

heartpoints_yarn_help() { echo "call the heartpoints-specific version of yarn to add / remove dependencies, etc"; }
heartpoints_yarn() { local args=$@
    if command_does_not_exist "yarn"; then
        npm_cli install yarn -g
    fi
    yarn "$@"
}

heartpoints_runWebPackDevServer(){
    heartpoints_yarn watch
}

ensureDockerCliConfiguredToRunningDaemon() {
    echo "WARN: Please ensure Docker daemon is running if it is not"
}

gitHeadIsDirty() {
    ! git diff-index --quiet HEAD > /dev/null
}

heartpoints_ensureCommitIsAppropriate() {
    if gitHeadIsDirty; then
        errorAndExit "error: uncommitted changes!"
    fi
}

heartpoints_buildAndTagImage() { local taggedImageName=$1; local shaToReportInHttpHeaders=$2
    ensureDockerCliConfiguredToRunningDaemon
    heartpoints_ensureCommitIsAppropriate
    docker build --build-arg commitSha="${shaToReportInHttpHeaders}" -t ${taggedImageName} .
}

heartpoints_dockerTestImage() { local taggedImageName=$1
    local testName="heartpointsTest"
    trap "docker stop ${testName} > /dev/null" EXIT
    docker run --detach --name "${testName}" --rm "${taggedImageName}"
    sleep 10
    docker exec "${testName}" bash ./heartpoints.sh test localhost:5001
}

heartpoints_prePushVerification_help() { echo "validates that local code is ready for pull request"; }
heartpoints_prePushVerification() {
    heartpoints_minikubeBuildDeployTest
}

heartpoints_onPullRequest() {
    heartpoints_dockerBuildTagAndTest
}

heartpoints_unitTest_help() { echo "run the mocha unit tests, which test without build / deploy"; }
heartpoints_unitTest() { local args="$@"
    heartpoints_yarn ts-mocha src/tests/**/*.ts "$@"
}

heartpoints_dockerBuildTagAndTest() {
    local imageRepo="circleci"
    local shaToBuild="$(git_currentSha)"
    local taggedImageName="$(heartpoints_taggedImageName ${imageRepo} ${shaToBuild})"
    heartpoints_buildAndTagImage "${taggedImageName}" "${shaToBuild}"
    heartpoints_dockerTestImage "${taggedImageName}"
}

heartpoints_onTestComplete() { local failureOrSuccess=$1
    echo """

    Test Suite ${failureOrSuccess}

    """
}

heartpoints_test() { local baseUrl=$1
    echo "Testing..."
    echo "Test homepage html file is 200..."
    echo "$(curl -L --insecure "${baseUrl}" --fail -o /dev/null)"
    echo "passed"
    echo "" 
    echo "Test bundle.js file is 200..." 
    echo "$(curl -L --insecure "${baseUrl}/bundle.js" --fail -o /dev/null)"
    echo "passed"
    echo "" 
    echo "Test commitSha presence in header matches current sha ($(git_currentSha)):"
    local headerOutput="$(curl -L --insecure -I "${baseUrl}?preventCache=$(date +%s)")"
    echo "$headerOutput"
    if echo "$headerOutput" | grep -i "commitSha: $(git_currentSha)"; then
        heartpoints_onTestComplete "passed"
    else
        heartpoints_onTestComplete "failed"
        return 1
    fi
}

heartpoints_onMasterMerge() { export gcpCicdServiceAccountCredentialsJson
    cicdProductionBuildDeployTest
}

heartpoints_minikubeRunTests_help() { echo "run tests against an existing minikube-hosted website"; }
heartpoints_minikubeRunTests() {
    heartpoints_test "$(heartpoints_urlOfMinikubeWebsite)"
}

heartpoints_createGKECluster_help() { echo "creates a GKE cluster. See README for prerequisites"; }
heartpoints_createGKECluster() {
    withinCloudSDK ./heartpoints.sh createGKECluster_commands
}

withinCloudSDK() { local commands=$@
    docker run -p 8001:8001 -v "$(pwd)":/heartpoints --rm -w /heartpoints google/cloud-sdk:latest "$@"
}

heartpoints_gcloud_kubectl() { local args=$@
    withinCloudSDK ./heartpoints.sh kubectl_commands "$@"
}

heartpoints_kubectl_commands() { local args=$@
    gcloud_cicdAccountLogin
    kubectl_install
    kubectl "$@"
}

heartpoints_createGKECluster_commands() {
    gcloud_cicdAccountLogin
    gcloud_cli beta container --project "heartpoints-org" \
        clusters create "heartpoints-org" \
        --zone "us-central1-a" \
        --username "admin" \
        --cluster-version "1.11.5-gke.5" \
        --machine-type "n1-standard-1" \
        --image-type "COS" \
        --disk-type "pd-standard" \
        --disk-size "30" \
        --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" \
        --num-nodes "1" \
        --enable-stackdriver-kubernetes \
        --enable-ip-alias \
        --network "projects/heartpoints-org/global/networks/default" \
        --subnetwork "projects/heartpoints-org/regions/us-central1/subnetworks/default" \
        --default-max-pods-per-node "110" \
        --addons HorizontalPodAutoscaling,HttpLoadBalancing,KubernetesDashboard \
        --enable-autoupgrade \
        --enable-autorepair \
        --maintenance-window "11:00"
}

heartpoints_runServer() {
    heartpoints_yarn start
}

errorAndExit() { local message=$1
    echo $message
    exit 1
}

heartpoints_gcr() {
    echo "gcr.io/heartpoints-org"
}

heartpoints_manualDeploy_help() { echo "interactive interview to deploy to production"; }
heartpoints_manualDeploy() { local gitSha=$1
    requiredParameter "gitSha" "${gitSha}" 
    heartpoints_deployToKubernetes "$(heartpoints_taggedImageName $(heartpoints_gcr) ${gitSha})"
}

stringReplace() { local originalString=$1; local stringToReplace=$2; local stringToPutInItsPlace=$3
    echo "$originalString" | sed "s~${stringToReplace}~${stringToPutInItsPlace}~"
}

fileReplace() { local fileName=$1; local stringToReplace=$2; local stringToPutInItsPlace=$3
    cat "${fileName}" | sed "s~${stringToReplace}~${stringToPutInItsPlace}~"
}

heartpoints_k8sResourceYaml() { local image=$1
    echo "$(fileReplace "heartpoints-k8s.yml" "{{image}}" "${image}")"
}

heartpoints_deployToKubernetes() { local image=$1
    echo "$(heartpoints_k8sResourceYaml "${image}")" | kubectl apply -f -
    echo "deployment request complete... to check status run './heartpoints.sh minikubeDashboard'"
}

heartpoints_pointToAndRunMinikubeDockerDaemon() {
    heartpoints_minikube_start
    eval $(minikube docker-env)
}

heartpoints_taggedImageName() { local imageRepository=$1; local gitSha=$2
    echo "${imageRepository}/heartpoints.org:${gitSha}"
}

heartpoints_manualProductionBuildDeployTest() {
    gcloud_manualLogin
    productionBuildDeployTest
}

cicdProductionBuildDeployTest() {
    gcloud_cicdAccountLogin
    productionBuildDeployTest
}

productionBuildDeployTest() {
    #TODO: DRY up wrt: heartpoints_minikubeBuildDeployTest
    local imageRepository="$(heartpoints_gcr)"
    local shaToBuild="$(git_currentSha)"
    local taggedImageName="$(heartpoints_taggedImageName ${imageRepository} ${shaToBuild})"
    heartpoints_buildAndTagImage "${taggedImageName}" "${shaToBuild}"
    docker push "${taggedImageName}"
    heartpoints_deployToKubernetes "${taggedImageName}"
    heartpoints_testUntilSuccess 120 15 heartpoints_test "http://35.244.131.133/" # This refers to the static loadbalancer IP in gcloud
}

errorIfEmpty() { local possiblyEmpty=$1; local errorMessage=$2
    if string_is_empty "${possiblyEmpty}"; then
        errorAndExit "${errorMessage}"
    fi
}

requiredParameter() { local parameterName=$1; local parameterValue=$2
    errorIfEmpty "${parameterValue}" "${parameterName} is required parameter"
}

heartpoints_buildAndPushCicdImage() {
    local imageURI="$(heartpoints_gcr)/cicd:1.0.1"
    docker build -t "$imageURI" -f cicd.Dockerfile .
    gcloud_manualLogin
    docker push "$imageURI"
}

heartpoints_minikubeDeployTest_help() { echo "<taggedImageName> - deploy image to mk and test it (defaults to image for head sha)"; }
heartpoints_minikubeDeployTest() { local taggedImageName=$1
    requiredParameter "taggedImageName" "${taggedImageName}" 
    heartpoints_deployToKubernetes "${taggedImageName}"
    heartpoints_testUntilSuccess 120 15 heartpoints_minikubeRunTests
}

heartpoints_testUntilSuccess() { local timeoutSeconds=$1; local interval=$2; local testCommand=${@:3}
    timer=0
    while true; do
        if "${@:3}"; then
            break
        elif [ $timer -ge $timeoutSeconds ]; then
            echo "Maximum retries exceeded. Test failed"
            exit 1
        fi
        echo "Test failed. A total of $timer seconds have elapsed. Attempting again after $interval seconds..."
        timer=$(($timer+$interval))
        sleep $interval
    done
}

heartpoints_minikubeBuildDeployTest_help() { echo "minikubeBuild, then minikubeDeployTest"; }
heartpoints_minikubeBuildDeployTest() {
    local shaToBuild="$(git_currentSha)"
    local taggedImageName="$(heartpoints_minikubeTaggedImageName ${shaToBuild})"
    heartpoints_minikubeBuild "${taggedImageName}" "${shaToBuild}"
    heartpoints_minikubeDeployTest "${taggedImageName}"
}

heartpoints_minikubeTaggedImageName() { local shaToBuild=$1
    requiredParameter "shaToBuild" "${shaToBuild}"
    local imageRepository="minikube"
    echo "$(heartpoints_taggedImageName ${imageRepository} ${shaToBuild})"
}

heartpoints_minikubeBuild_help() { echo "<taggedImageName> using minikube's docker daemon, build image and tag with minikube metadata"; }
heartpoints_minikubeBuild() { local taggedImageName=$1; local shaToReportInHttpHeaders=$2
    requiredParameter "taggedImageName" "${taggedImageName}"
    requiredParameter "shaToReportInHttpHeaders" "${shaToReportInHttpHeaders}"
    heartpoints_pointToAndRunMinikubeDockerDaemon
    heartpoints_pointToAndRunMinikubeDockerDaemon
    heartpoints_buildAndTagImage "${taggedImageName}" "${shaToReportInHttpHeaders}"
}

heartpoints_minikubeDestroyEnvironment_help() { echo "if minikube dev environment is running, destroys it"; }
heartpoints_minikubeDestroyEnvironment() {
    heartpoints_minikube delete
}

heartpoints_urlOfMinikubeWebsite() {
    echo "https://$(heartpoints_minikube ip)"
}

heartpoints_minikubeOpenWebsite_help() { echo "assuming site is running in minikube locally, open web browser to home page"; }
heartpoints_minikubeOpenWebsite() {
    open "$(heartpoints_urlOfMinikubeWebsite)"
}

heartpointpoints_log_path() {
    local logsPath="$(devEnvironmentPath)/logs"
    mkdir -p "${logsPath}"
    echo "${logsPath}"
}

minikubeInstallLogPath() {
    echo "$(heartpointpoints_log_path)/mikikube-installation.log"
}

heartpoints_minikube_update() {
    if heartpoints_minikube update-check; then
        brew_cask update minikube
    fi
}

heartpoints_updateDependencies() {
    heartpoints_yarn
    heartpoints_minikube_update
}

heartpoints_minikube() { local args=$@
    mkdir -p "$(heartpointpoints_log_path)"
    minikube_install > "$(minikubeInstallLogPath)" 2>&1
    minikube "$@"
}

heartpoints_minikubeIngressNotEnabled() {
    ! heartpoints_minikube addons list | grep "ingress: enabled" > /dev/null
}

heartpoints_minikubeEnableIngress() {
    if heartpoints_minikubeIngressNotEnabled; then
        heartpoints_minikube addons enable ingress
    fi
}

heartpoints_minikubeDashboard_help() { echo "open minikube dashboard in web browser"; }
heartpoints_minikubeDashboard() {
    heartpoints_minikube dashboard 
}

heartpoints_minikube_start() {
    if ! heartpoints_minikube_isRunning; then
        heartpoints_minikube start
    fi
    heartpoints_minikubeEnableIngress
}

heartpoints_minikube_stop() {
    if heartpoints_minikube_isRunning; then
        heartpoints_minikube stop
    fi
}

heartpoints_minikube_isRunning() {
    heartpoints_minikube status | grep "host: Running"
}

heartpoints_model() {
    heartpoints_yarn install
    heartpoints_yarn ts-node src/heartpoints-cli.ts
}

heartpoints_g() { local message=$@ 
    git add -A
    git commit -m "${message}"
}

# Authentication

gcloud_cicdAccountLogin() { export gcpCicdServiceAccountCredentialsJson
    if [ -v gcpCicdServiceAccountCredentialsJson ]; then
        trap "rm gcpCicdServiceAccountCredentialsJson.json" EXIT
        echo "$gcpCicdServiceAccountCredentialsJson" > gcpCicdServiceAccountCredentialsJson.json
        gcloud_cli auth activate-service-account "$(cicdServiceAccountEmail)" --key-file=gcpCicdServiceAccountCredentialsJson.json
        gcloud_configure
    else
        echo "Unable to log into service account - gcpCicdServiceAccountCredentialsJson is not set"
        exit 1
    fi
}

gcloud_manualLogin() {
    gcloud_cli auth login
    gcloud_configure
}

gcloud_configure() {
    gcloud_cli config set project heartpoints-org
    gcloud_cli auth configure-docker
    gcloud_cli container clusters get-credentials heartpoints-org --zone us-central1-a --project heartpoints-org
}

# Misc functions

brew_cask_caskIsInstalled() { local caskName=$1
    heartpoints_brew cask list | grep "${caskName}" > "$(heartpointpoints_log_path)/brew_cask_caskIsInstalled.log" 2>&1
}

brew_cask_installCask() { local caskName=$1
    if command_does_not_exist "${caskName}"; then
        brew_cask install "${caskName}"
    fi
}

brew_app_dir_path() {
    local brewAppDirPath="$(devEnvironmentPath)/brewAppDir"
    mkdir -p "${brewAppDirPath}"
    echo "${brewAppDirPath}"
}

brew_cask() { local args="${@}"
    brew_cask_installCaskroom
    heartpoints_brew cask --appdir "$(brew_app_dir_path)" "$@"
}

devEnvironmentPath() {
    local devEnvironmentPath="./devEnvironment"
    mkdir -p "${devEnvironmentPath}"
    echo "${devEnvironmentPath}"
}

brew_cask_installCaskroom() {
    if ! heartpoints_brew info cask &>/dev/null; then
        mkdir -p "$(devEnvironmentPath)"
        heartpoints_brew tap caskroom/cask --appdir "$(brew_app_dir_path)"
    fi
}

heartpoints_brew() { local args="$@"
    if command_does_not_exist "$(homebrew_cli_path)"; then
        brew_install_brew_itself
    fi
    $(homebrew_cli_path) "$@"
}

homebrew_cli_path() {
    echo "$(homebrew_install_dir)/bin/brew"
}

homebrew_install_dir() {
    local homebrewInstallDir="$(devEnvironmentPath)/homebrew"
    mkdir -p "${homebrewInstallDir}"
    echo "${homebrewInstallDir}"
}

brew_install_brew_itself() {
    curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C "$(homebrew_install_dir)"
}

command_does_not_exist() { local possibleCommand=$1
    ! [ -x "$(command -v ${possibleCommand})" ]
}

file_does_not_exist() { local possibleFilePath=$1
    ! [ -e "${possibleFilePath}" ]
}

gcloud_install() {
    if command_does_not_exist "gcloud"; then
        heartpoints_brew cask install google-cloud-sdk
    fi
}

gcloud_cli() { local args=$@
    gcloud_install   
    gcloud "$@"
}

git_currentSha() {
    echo "$(git rev-parse HEAD)"
}

git_working_directory_is_clean() {
    [ -z "$(git status --porcelain)" ]
}

kubectl_install() {
    brew_install "kubernetes-cli"
}

minikube_install() {
    kubectl_install
    virtualbox_install
    if command_does_not_exist minikube; then
        brew_cask_installCask minikube
    fi
}

nodejs_ensureCorrectVersion() {
    if command_does_not_exist "node" || ! strings_are_equal "$(node -v)" "$(cat .nvmrc)"; then
        nvm_installAndUseVersionInNvmRC
    fi
}

npm_cli() { local args=$@
    nodejs_ensureCorrectVersion   
    npm "$@"
}

nvm_download_and_install() {
    touch ~/.bash_profile
    curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh | bash
}

nvm_installAndUseVersionInNvmRC() {
    nvm_load
    set +e
    nvm install 
    set -e
    nvm use
}

nvm_load() {
    if command_does_not_exist "nvm"; then
        if file_does_not_exist "$(nvm_script_path)"; then
            nvm_download_and_install
        fi
        set +e
        nvm_load_existing_nvm
        set -e
    fi
}

nvm_load_existing_nvm() {
    export NVM_DIR="$(nvm_script_dir)"
    [ -s "$(nvm_script_path)" ] && \. "$(nvm_script_path)"
}

nvm_script_dir() {
    echo "$HOME/.nvm"
}

nvm_script_path() {
    echo "$(nvm_script_dir)/nvm.sh"
}

string_is_empty() { local possiblyEmptyString=$1
    [[ -z "${possiblyEmptyString}" ]]
}

strings_are_equal() { local string1=$1; local string2=$2
    [ "${string1}" = "${string2}" ]
}

strings_are_not_equal() { local string1=$1; local string2=$2
    ! strings_are_equal "${string1}" "${string2}"
}

virtualbox_install() {
    brew_cask_installCask virtualbox
}

cicdServiceAccountEmail() {
    echo "cicd-353@heartpoints-org.iam.gserviceaccount.com"
}

heartpoints "$@"