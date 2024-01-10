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
        docker { 
            image 'salesforce/cli:nightly-full'
            args '-u 0'
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
        SFDX_USE_GENERIC_UNIX_KEYCHAIN = true
        ENVIRONMENT_NAME = "${getEnvironment().environment}"
        TOKENFILENAME = "${getEnvironment().tokenFileName}"

    }

    stages {

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
                    }
                    catch(Ex){
                        echo "$Ex"
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
                        sh "sf force:auth:logout -p --targetusername $USERNAME"
                    }
                    catch(Ex) {
                        echo "$Ex"
                    }
                }
                sh "sf force:auth:jwt:grant --clientid $CLIENT_ID --username $USERNAME --jwtkeyfile $JWT_SECRET_FILE --instanceurl $INSTANCE_URL"
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
                sh "sf force:source:deploy --manifest force-app/main/default/package.xml --loglevel error --targetusername $USERNAME --checkonly --testlevel RunLocalTests"
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
                sh "sf force:source:deploy --manifest force-app/main/default/package.xml --loglevel error --targetusername $USERNAME"
            }
        }

        /*
        If build is triggered by a merge, run local tests (after commit has been deployed in stage above)
        */

        stage('Post Deploy Test Run') {
            when {
                anyOf {
                    branch "dev"
                    branch "sit"
                    branch "uat"
                    branch "main";
                }
            }
            steps {
                echo "Running local tests"
                sh "sf force:apex:test:run --loglevel error --resultformat human --testlevel RunLocalTests --targetusername $USERNAME"
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
                    }
                    catch(Ex) {
                        echo "$Ex"
                    }
                }
            }
        }
    }

    /*
    Send email to commit author(s) of successful/failed build
    */
    
    post {
        always {
            archiveArtifacts(artifacts: '**/*.*')
        }
        success {            
            echo "Build success"
            script{
                if (env.BRANCH_NAME == 'dev' ) {
                    echo "Successfully built on development"
                    emailext( 
                        body: 'Deployment to the ' + "$ENVIRONMENT_NAME" + ' environment has completed successfully.', 
                        recipientProviders: [[$class: 'CulpritsRecipientProvider']],
                        subject: 'Successful Deployment - $PROJECT_NAME - #$BUILD_NUMBER - Environment: '+ "$ENVIRONMENT_NAME"
                    )
                }
                if (env.BRANCH_NAME.startsWith("PR")) {
                    echo "Successfully built PR"
                    emailext( 
                        body: 'Validation of Pull request to the ' + "$env.BRANCH_NAME" + ' environment was successful.', 
                        recipientProviders: [[$class: 'CulpritsRecipientProvider']],
                        subject: 'Successful PR Validation - $PROJECT_NAME - #$BUILD_NUMBER - Environment: '+ "$ENVIRONMENT_NAME"
                    )
                }
            }
        }
        failure {
            echo "Build failed"
            emailext(
                body: 'Deployment/validation to the ' + "$ENVIRONMENT_NAME" + ' environment has FAILED. \n\n ${CHANGES} \n\n -------------------------------------------------- \n${BUILD_LOG, maxLines=100, escapeHtml=false}', 
                recipientProviders: [[$class: 'CulpritsRecipientProvider']],
                subject: 'Build FAILED: $PROJECT_NAME - #$BUILD_NUMBER - Environment: '+ "$ENVIRONMENT_NAME"
            )
        }
    }
}

/*
Helper function that returns back the environment specifics needed based on the branch name
*/

def getEnvironment() {
    def envToDeploy = [:]

    switch( env.BRANCH_NAME ) {
        case 'dev':
            echo "Development branch credentials"
            envToDeploy.username = "$DEVELOPMENT_SF_USERNAME"
            envToDeploy.instanceURL = "$DEVELOPMENT_SF_URL"
            envToDeploy.environment = "DEV"
            envToDeploy.tokenFileName = "DEV"
            envToDeploy.clientIdKey = "$DEVELOPMENT_SECRET_KEY_FOR_CLIENT_ID"
            break
        case 'sit':
            echo "SIT branch credentials"
            envToDeploy.username = "$SIT_SF_USERNAME"
            envToDeploy.instanceURL = "$SIT_SF_URL"
            envToDeploy.environment = "SIT"
            envToDeploy.tokenFileName = "SIT"
            envToDeploy.clientIdKey = "$SIT_SECRET_KEY_FOR_CLIENT_ID"
            break
        case 'uat':
            echo "UAT branch credentials"
            envToDeploy.username = "$UAT_SF_USERNAME"
            envToDeploy.instanceURL = "$UAT_SF_URL"
            envToDeploy.environment = "UAT"
            envToDeploy.tokenFileName = "UAT"
            envToDeploy.clientIdKey = "$UAT_SECRET_KEY_FOR_CLIENT_ID"
            break
        case 'main':
            echo "Production branch credentials"
            envToDeploy.username = "$PROD_SF_USERNAME"
            envToDeploy.instanceURL = "$PROD_SF_URL"
            envToDeploy.environment = "PROD"
            envToDeploy.tokenFileName = "PROD"
            envToDeploy.clientIdKey = "$PROD_SECRET_KEY_FOR_CLIENT_ID"
            break
        case ~/PR.*/:
            echo "This is a PR"
            envToDeploy = getPREnvironment()
            break
        default:
            echo "No setting for this branch - " + env.BRANCH_NAME
            break
    }

    return envToDeploy
}
/*
Helper function that returns back the environment specifics needed for PR destination branches
*/

def getPREnvironment() {
    def envToDeploy = [:]

    echo "Target = " + env.CHANGE_TARGET
    envToDeploy.environment = "Pull Request"

    switch( env.CHANGE_TARGET ) {
        case 'dev':
            echo "Development branch credentials"
            envToDeploy.username = "$DEVELOPMENT_SF_USERNAME"
            envToDeploy.instanceURL = "$DEVELOPMENT_SF_URL"
            envToDeploy.tokenFileName = "DEV"
            envToDeploy.clientIdKey = "$DEVELOPMENT_SECRET_KEY_FOR_CLIENT_ID"
            break
        case 'sit':
            echo "SIT branch credentials"
            envToDeploy.username = "$SIT_SF_USERNAME"
            envToDeploy.instanceURL = "$SIT_SF_URL"
            envToDeploy.tokenFileName = "SIT"
            envToDeploy.clientIdKey = "$SIT_SECRET_KEY_FOR_CLIENT_ID"
            break
        case 'uat':
            echo "UAT branch credentials"
            envToDeploy.username = "$UAT_SF_USERNAME"
            envToDeploy.instanceURL = "$UAT_SF_URL"
            envToDeploy.tokenFileName = "UAT"
            envToDeploy.clientIdKey = "$UAT_SECRET_KEY_FOR_CLIENT_ID"
            break
        case 'main':
            echo "Production branch credentials"
            envToDeploy.username = "$PROD_SF_USERNAME"
            envToDeploy.instanceURL = "$PROD_SF_URL"
            envToDeploy.tokenFileName = "PROD"
            envToDeploy.clientIdKey = "$PROD_SECRET_KEY_FOR_CLIENT_ID"
            break
        case ~/PR.*/:
            echo "This is a PR"
            envToDeploy = getPREnvironment()
            break
        default:
            echo "No setting for this branch - " + env.CHANGE_TARGET
            envToDeploy.tokenFileName = "DEV"
            break
    }

    return envToDeploy
}
