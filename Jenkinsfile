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
        JWT_SECRET_FILE = credentials("$SERVER_KEY")
        CLIENT_ID = "${getEnvironment().clientIdKey}"
        USERNAME = "${getEnvironment().username}"
        INSTANCE_URL = "${getEnvironment().instanceURL}"
        ENVIRONMENT_NAME = "${getEnvironment().environment}"
        TOKENFILENAME = "${getEnvironment().tokenFileName}"
        GIT_MERGE_DEST = "${getEnvironment().mergeDestination}"
        GIT_COMMIT_MSG = $(git log --format=%B -n 1 $GIT_COMMIT)

    }

    stages {

        /*
        Check for Salesforce CLI update
        */
        stage('Update CLI') {
            steps {
                script { 
                    try {
                        sh "npm update --global @salesforce/cli"
                        sh "echo y | sf plugins:install sfdx-git-delta"
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
        SFDX force logout (in case previous build failed before logout), then authorise destination org with JWT 
        */
        
        stage('Authorise') {
            steps {
                script {
                    try {
                        sh "sfdx force:auth:logout -p --targetusername $USERNAME"
                    } catch(Exception e){
                        echo "Exception occured: " + e.toString()
                    }
                }
                sh "sf force:auth:jwt:grant --clientid $CLIENT_ID --username $USERNAME --jwtkeyfile $JWT_SECRET_FILE --instanceurl $INSTANCE_URL"
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
                echo "Validating commit..."
                sh "sf force:org:list" // https://github.com/forcedotcom/cli/issues/899
                sh "sf force:source:deploy --manifest ./manifest/package.xml --loglevel error --targetusername $USERNAME --checkonly --testlevel NoTestRun  --predestructivechanges ./destructiveChanges/destructiveChangesPre.xml --postdestructivechanges ./destructiveChanges/destructiveChangesPost.xml --ignorewarnings"
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
                echo "Validating..."
                sh "sf force:source:deploy --manifest ./manifest/package.xml --loglevel error --targetusername $USERNAME --checkonly --testlevel RunLocalTests --predestructivechanges ./destructiveChanges/destructiveChangesPre.xml --postdestructivechanges ./destructiveChanges/destructiveChangesPost.xml --ignorewarnings"
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
                echo "Deploying..."
                sh "sf force:source:deploy --manifest force-app/main/default/package.xml --loglevel error --targetusername $USERNAME --testlevel RunLocalTests --predestructivechanges ./destructiveChanges/destructiveChangesPre.xml --postdestructivechanges ./destructiveChanges/destructiveChangesPost.xml --ignorewarnings"
            }
        }

        /*
        Logout from org
        */
        
        stage('Logout') {
            steps {
                script {
                    try {
                        sh "sf force:auth:logout -p --targetusername $USERNAME"
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
