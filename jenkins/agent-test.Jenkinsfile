pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: shell
    image: alpine:3.20
    command:
    - sleep
    args:
    - 99d
'''
            defaultContainer 'shell'
        }
    }

    stages {
        stage('Dynamic agent test') {
            steps {
                sh 'echo "agent-host=$(hostname)"'
                sh 'uname -a'
                sh 'cat /etc/os-release'
            }
        }
    }
}
