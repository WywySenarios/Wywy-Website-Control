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
          sh 'scripts/tests/ansible/pytest.sh'
          sh 'scripts/tests/ansible/mypy.sh'
        }
      }
    }

    stage('tofu-checks') {
      steps {
        withChecks('tofu-checks') {
          sh 'scripts/tests/terraform/fmt.sh'
          sh 'scripts/tests/terraform/validate.sh'
          sh 'scripts/tests/terraform/test.sh'
        }
      }
    }

    stage('k8s-manifests') {
      agent { label 'manifests' }
      steps {
        withChecks('k8s-manifests') {
          sh 'scripts/tests/k8s-yaml.sh'
          sh 'scripts/tests/k8s-schema.sh'
          sh 'scripts/tests/k8s-sops.sh'
          sh 'scripts/tests/k8s-policy.sh'
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
