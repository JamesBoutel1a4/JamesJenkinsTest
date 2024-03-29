/*
Branching Model: Branch-per-Environment
Author: Slalom
*/

pipeline {
    
    /*
    Defines the Jenkins agent
    For more information on dockers in Jenkins: https://jenkins.io/doc/book/pipeline/docker/
    */

    agent {
        ecs {
            inheritFrom 'jenkins-agent-sf'
            environments([[name: 'DIND', value: 'true']])
            }
        }


    /*
    Environment variables global to the whole pipeline go here
    */
    environment {

        PATH = "/usr/local/bin:$PATH"
        JWT_SECRET_FILE = credentials("$SERVER_KEY") //will need to do getEnvironment for each environment 
        CLIENT_ID = "${getEnvironment().clientIdKey}"
        USERNAME = "${getEnvironment().username}"
        INSTANCE_URL = "${getEnvironment().instanceURL}"
        ENVIRONMENT_NAME = "${getEnvironment().environment}"
        TOKENFILENAME = "${getEnvironment().tokenFileName}"
        GIT_MERGE_DEST = "${getEnvironment().mergeDestination}"
    }

    stages {

        /*
        Check for Salesforce CLI update
        */
        stage('Update CLI') {
            steps {
                script { 
                    try {
                        env.GIT_COMMIT_MSG = sh (script: 'git log -1 --pretty=%B ${GIT_COMMIT}', returnStdout: true).trim()
                        sh "echo y | sf plugins:install sfdx-git-delta"
                        sh "npm install @salesforce/cli" //potentially cache the npm directory and store it somewhere?
                        sh "npm update --global @salesforce/cli"
                    } catch(Exception e){
                        echo "Exception occured: " + e.toString()
                    }
                }
            }
        }
        
        /*
        Use the relevant env_tokens .csv for branch, to search project metadata for tokenise keys and replace. 
        */
        stage('Tokenise') {
            steps {
                script {
                    try {
                        sh "ls -l"
                        sh "ls -l ./scripts/tokenise_metadata.sh"
                        sh "chmod 755 ./scripts/tokenise_metadata.sh"
                        sh "ls -l ./scripts/tokenise_metadata.sh"
                        echo "./scripts/tokenise_metadata.sh ./env_tokens/${TOKENFILENAME}.csv"
                        sh "./scripts/tokenise_metadata.sh ./env_tokens/${TOKENFILENAME}.csv"
                    } catch(Exception e){
                        echo "Exception occured: " + e.toString()
                    }
                }
            }
        }

        /*
        SFDX org logout (in case previous build failed before logout), then authorise destination org with JWT 
        */
        stage('Authorise') {
            steps {
                script {
                    try {
                        sh "sfdx org:logout -p --target-org $USERNAME"
                    } catch(Exception e){
                        echo "Exception occured: " + e.toString()
                    }
                }
                sh "sf org:login:jwt --client-id $CLIENT_ID --username $USERNAME --jwt-key-file $JWT_SECRET_FILE --instance-url $INSTANCE_URL"
            }
        }

        /*  
        Create a delta directory for delta deployments
        */
        stage('Create Delta Dir'){
            steps {
                script {
                    if (env.GIT_COMMIT_MSG.contains("bypass-delta")){
                        echo "Bypassing creation of delta directory"
                    } 
                    else{
                        echo "Creating delta directory..."
                        echo "Git merge destination -- ${GIT_MERGE_DEST}"
                        echo "Git branch -- ${env.GIT_BRANCH}"
                        try{
                            sh "mkdir delta-deployment"
                            if(env.GIT_MERGE_DEST == env.GIT_BRANCH){ //merge commit
                                sh "sfdx sgd:source:delta --to 'HEAD' --from 'HEAD~1' --output 'delta-deployment' --generate-delta"
                            }else if(env.BRANCH_NAME.contains("PR-")){
                                sh "git fetch origin ${GIT_MERGE_DEST}:refs/remotes/origin/${GIT_MERGE_DEST}"
                                sh "git fetch origin ${env.CHANGE_BRANCH}:refs/remotes/origin/${env.CHANGE_BRANCH}"
                                sh "git branch -a"
                                sh "sfdx sgd:source:delta --to origin/${env.CHANGE_BRANCH} --from origin/${GIT_MERGE_DEST} --output 'delta-deployment' --generate-delta"
                            }else{
                                sh "git fetch origin ${GIT_MERGE_DEST}:refs/remotes/origin/${GIT_MERGE_DEST}"
                                sh "git fetch origin ${env.GIT_BRANCH}:refs/remotes/origin/${env.GIT_BRANCH}"
                                sh "git branch -a"
                                sh "sfdx sgd:source:delta --to origin/${env.GIT_BRANCH} --from origin/${GIT_MERGE_DEST} --output 'delta-deployment' --generate-delta"
                            }
                            echo "Delta directory result..."
                            sh "ls -R delta-deployment"
                        } catch(Exception e){
                            echo "Exception occured: " + e.toString()
                        }
                    } 
                }
            }
        }

        /*  
        If build is triggered by a feature/ branch commit, run a validation to CI sandbox
        */
        stage('Feature Validation') {
            when {
                anyOf {
                    branch "feature/*";
                }
            }
            steps {
                script{
                    if(env.GIT_COMMIT_MSG.contains("bypass-delta")){
                        echo "Full Validation..."
                        sh "sf project:deploy:start --source-dir force-app/main/default --target-org $USERNAME --dry-run --test-level RunLocalTests --ignore-warnings --verbose"
                    }else{
                        echo "Validating commit..."
                        sh "sf org:list" // https://github.com/forcedotcom/cli/issues/899
                        sh "sf project:deploy:start --source-dir delta-deployment --target-org $USERNAME --dry-run --test-level RunLocalTests --ignore-warnings --verbose"
                    }
                }
            }
        }

        /*
        If build is triggered by a PR, run a validation to destination branch and run local tests
        */
        stage('Pull Request Validation') {
            when {
                anyOf {
                    branch "PR*";
                }
            }
            steps {
                script{
                    if(env.GIT_COMMIT_MSG.contains("bypass-delta")){
                        echo "Full Validation..."
                        sh "sf project:deploy:start --source-dir force-app/main/default --target-org $USERNAME --dry-run --test-level RunLocalTests --ignore-warnings --verbose"
                    }else{
                        echo "Validating commit..."
                        sh "sf force:org:list" // https://github.com/forcedotcom/cli/issues/899
                        sh "sf project:deploy:start --source-dir delta-deployment --target-org $USERNAME --dry-run --test-level RunLocalTests --ignore-warnings --verbose"
                    }
                }
            }
        }

        /*
        If build is triggered by a merge, deploy to destination branch 
        */
        stage('Deploy') {
            when {
                anyOf {
                    branch "dev"
                    branch "sit"
                    branch "uat"
                    branch "main";
                }
            }
            steps {
                script{
                    if(env.GIT_COMMIT_MSG.contains("bypass-delta")){
                        echo "Full Deployment..."
                        sh "sf project:deploy:start --source-dir force-app/main/default --target-org $USERNAME --test-level RunLocalTests --ignore-warnings --verbose"
                    }else{
                        echo "Delta Deployment..."
                        sh "sf project:deploy:start --source-dir delta-deployment --target-org $USERNAME --test-level RunLocalTests --ignore-warnings --verbose"
                    }
                }
            }
        }

        /*
        Logout from org
        */
        stage('Logout') {
            steps {
                script {
                    try {
                        sh "sf org:logout -p --target-org $USERNAME"
                    } catch(Exception e){
                        echo "Exception occured: " + e.toString()
                    }
                }
            }
        }
    }
}

/*
Helper function that returns back the environment specifics needed based on the branch name
*/

def getEnvironment() {
    def envToDeploy = [:]

    switch( env.BRANCH_NAME ) {
        case ~/PR.*/:
            echo "This is a PR"
            envToDeploy = getPREnvironment()
            break
        case ~/feature\/.*/:
            echo "This is a feature branch, using Development credentials"
            envToDeploy.username = "$DEVELOPMENT_SF_USERNAME"
            envToDeploy.instanceURL = "$DEVELOPMENT_SF_URL"
            envToDeploy.environment = "DEV"
            envToDeploy.tokenFileName = "DEV"
            envToDeploy.clientIdKey = "$DEVELOPMENT_SECRET_KEY_FOR_CLIENT_ID"
            envToDeploy.mergeDestination = "dev"
            break
        case 'dev':
            echo "Development branch credentials"
            envToDeploy.username = "$DEVELOPMENT_SF_USERNAME"
            envToDeploy.instanceURL = "$DEVELOPMENT_SF_URL"
            envToDeploy.environment = "DEV"
            envToDeploy.tokenFileName = "DEV"
            envToDeploy.clientIdKey = "$DEVELOPMENT_SECRET_KEY_FOR_CLIENT_ID"
            envToDeploy.mergeDestination = "dev"
            break
        case 'sit':
            echo "SIT branch credentials"
            envToDeploy.username = "$SIT_SF_USERNAME"
            envToDeploy.instanceURL = "$SIT_SF_URL"
            envToDeploy.environment = "SIT"
            envToDeploy.tokenFileName = "SIT"
            envToDeploy.clientIdKey = "$SIT_SECRET_KEY_FOR_CLIENT_ID"
            envToDeploy.mergeDestination = "sit"
            break
        case 'uat':
            echo "UAT branch credentials"
            envToDeploy.username = "$UAT_SF_USERNAME"
            envToDeploy.instanceURL = "$UAT_SF_URL"
            envToDeploy.environment = "UAT"
            envToDeploy.tokenFileName = "UAT"
            envToDeploy.clientIdKey = "$UAT_SECRET_KEY_FOR_CLIENT_ID"
            envToDeploy.mergeDestination = "uat"
            break
        case 'main':
            echo "Production branch credentials"
            envToDeploy.username = "$PROD_SF_USERNAME"
            envToDeploy.instanceURL = "$PROD_SF_URL"
            envToDeploy.environment = "PROD"
            envToDeploy.tokenFileName = "PROD"
            envToDeploy.clientIdKey = "$PROD_SECRET_KEY_FOR_CLIENT_ID"
            envToDeploy.mergeDestination = "main"
            break
        default:
            echo "No setting for this branch - " + env.BRANCH_NAME
            currentBuild.result = "ABORTED"
            throw new Exception("No setting for this branch - " + env.BRANCH_NAME)
    }

    return envToDeploy
}
/*
Helper function that returns back the environment specifics needed for PR destination branches
*/

def getPREnvironment() {
    def envToDeploy = [:]

    echo "Target = " + env.CHANGE_TARGET

    switch( env.CHANGE_TARGET ) {
        case 'dev':
            echo "Development branch credentials"
            envToDeploy.username = "$DEVELOPMENT_SF_USERNAME"
            envToDeploy.instanceURL = "$DEVELOPMENT_SF_URL"
            envToDeploy.tokenFileName = "DEV"
            envToDeploy.clientIdKey = "$DEVELOPMENT_SECRET_KEY_FOR_CLIENT_ID"
            envToDeploy.mergeDestination = "dev"

            break
        case 'sit':
            echo "SIT branch credentials"
            envToDeploy.username = "$SIT_SF_USERNAME"
            envToDeploy.instanceURL = "$SIT_SF_URL"
            envToDeploy.tokenFileName = "SIT"
            envToDeploy.clientIdKey = "$SIT_SECRET_KEY_FOR_CLIENT_ID"
            envToDeploy.mergeDestination = "sit"
            break
        case 'uat':
            echo "UAT branch credentials"
            envToDeploy.username = "$UAT_SF_USERNAME"
            envToDeploy.instanceURL = "$UAT_SF_URL"
            envToDeploy.tokenFileName = "UAT"
            envToDeploy.clientIdKey = "$UAT_SECRET_KEY_FOR_CLIENT_ID"
            envToDeploy.mergeDestination = "uat"
            break
        case 'main':
            echo "Production branch credentials"
            envToDeploy.username = "$PROD_SF_USERNAME"
            envToDeploy.instanceURL = "$PROD_SF_URL"
            envToDeploy.tokenFileName = "PROD"
            envToDeploy.clientIdKey = "$PROD_SECRET_KEY_FOR_CLIENT_ID"
            envToDeploy.mergeDestination = "main"
            break
        default:
            echo "No setting for this branch - " + env.CHANGE_TARGET
            currentBuild.result = "ABORTED"
            throw new Exception("No setting for this branch - " + env.CHANGE_TARGET)
    }

    return envToDeploy
}
