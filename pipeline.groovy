pipeline {
    agent any
    environment {
    		BALLS = "Salty"
    }
    stages {
       stage('Configure') {
            steps {
		dir ('./') {
		   script {
		   	  sh "echo 'PWD =' ${pwd()}"
		       	  def cmd = './build-vtk-dashboard.sh --configure --builddir $buildDir'
			  if ( params.Debug ) {
			     cmd = cmd + " --debug"
			  //sh "echo 'CMD = ' ${cmd}"
			  }
			  if ( params.Custom ) {
			     cmd = cmd + " --custom"
			  }
			  if ( params.cleanBuild ) {
			     cmd = cmd + " --clean"
			  }
			  sh cmd
		   }
		}
            }
	}
       stage('Build') {
            steps {
		dir ('./') {
		   script {
			  def cmd = './build-vtk-dashboard.sh --make --display $xDisplay --flags $buildFlags --model $buildModel --name $buildName --builddir $buildDir'
			  if ( params.runTests ) {
		       	     cmd = cmd + " --testing"
		   	  }
			  if ( params.Debug ) {
			     cmd = cmd + " --debug"
		   	  }
			  if ( params.Custom ) {
			     cmd = cmd + " --custom"
			  }
			  if ( params.cleanBuild ) {
			     cmd = cmd + " --clean"
			  }
			  if ( params.dropSite ) {
			     cmd = cmd + " --dropsite $dropSite"
			  }
			  if ( params.dropLocation ) {
			     cmd = cmd + " --droploc $dropLocation"
			  }
			  if ( params.siteName  ) {
			     cmd = cmd + " --site $siteName"
			  }

			  sh cmd
		   }
		}
	    }
        }
    }

    post {
        always {
	    //junit 'build/reports/**/*.xml'
	    //deleteDir() /* clean up our workspace */
            echo 'Post: Build finished.'
        }
        success {
            echo 'Post: Build successful.'
        }
        failure {
            echo 'Post: Build failed.'
        }
        unstable {
            echo 'Post: Build marked as unstable.'
        }
        changed {
            echo 'Post: Pipeline state has changed.'
            //echo 'For example, if the Pipeline was previously failing but is now successful'
        }
    }

}
