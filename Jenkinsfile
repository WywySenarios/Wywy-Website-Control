pipeline {
  agent { label 'generic' }

  options {
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '30'))
  }

  stages {
    stage('betterleaks') {
      agent { label 'betterleaks' }
      steps {
        withChecks('betterleaks') {
          sh 'betterleaks git . --config .betterleaks.toml --redact --no-banner --verbose'
        }
      }
    }

    stage('ansible-code-check') {
      steps {
        withChecks('ansible-code-check') {
          sh './scripts/install/ansible.sh'
          sh 'scripts/tests/ansible/lint.sh'
          sh 'scripts/tests/ansible/ruff.sh'
          sh 'scripts/tests/ansible/syntax.sh'
        }
      }
    }
  }

  post {
    always {
      cleanWs()
    }
  }
}
