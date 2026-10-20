pipeline {
  agent { label 'generic' }

  options {
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '30'))
  }

  stages {
    stage('gitleaks') {
      steps {
        sh 'gitleaks detect --source . --config .gitleaks.toml --redact --no-banner --verbose'
      }
    }

    stage('ansible') {
      steps {
        sh './scripts/install/ansible.sh'
        sh 'for step in scripts/tests/ansible/*.sh; do "$step"; done'
      }
    }
  }

  post {
    always {
      cleanWs()
    }
  }
}
