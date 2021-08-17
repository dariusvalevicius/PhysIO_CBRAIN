# MATLAB Tool Integration into CBRAIN

TABLE OF CONTENT

I. COMMAND LINE INTERFACE OF A TOOL    1
II. COMPILATION    2
III CONTAINERIZE    2
IV FORMALIZE COMMAND LINE    3
V BEST PRACTICES


# I. PROVIDE COMMAND LINE INTERFACE

While some researchers might have a GUI based tool or a set of loose scripts which they modify each time, currently CBRAIN supports linux (bash) command line tools. Hence it is best to create a command line version of your tool, something one can execute from a unix terminal for example

 > matlab -nosplash -nodesktop MyGreatTool.m  input_folder output_folder param1 param2

Obviously, one needs to specify full paths if the system is not set up to find MATLAB itself and/or  MATLAB code of the tool.

Use positional or named parameter, if you like, such as --input --output --baseline …. see https://github.com/big-data-lab-team/CBRAIN-plugins-eeg/blob/master/CBRAIN_task_descriptors/qeeg.json
for an example. Some tool developers prefer to have a few mandatory parameters (such as input-output), and rest of them as named parameters,  see https://github.com/big-data-lab-team/CBRAIN-plugins-eeg/blob/master/CBRAIN_task_descriptors/best.json

The MATLAB command line parsing is documented at
https://www.mathworks.com/help/MATLAB/ref/inputparser.html
https://people.umass.edu/whopper/posts/better-matlab-functions-with-the-inputparser-class/
If you are comfortable with python, you might find it easier to build additional python or other wrap script than parse with matlab.

An example of MATLAB code for parameter parsing is 

https://gitlab.com/multifunkimlab/best/blob/master/BEst.m

To process the command line parameters you can use MATLAB command line parser
Sometimes we use python to process the command line instead 

https://gitlab.com/multifunkimlab/best/blob/master/BEst.m

# II. COMPILATION 

The purpose of compilation is the ability to run your tool without installing MATLAB/having a license. Not all computation resources offer MATLAB.

Install MATLAB Compiler Toolkit if you do not have it (click add then select among other plugins)
Read MATLAB documentation https://www.mathworks.com/help/compiler/index.html about basics of MATLAB Compiler, Standalone Apps, Runtime ( skip everything about Spark, Hadoop etc)
Select your main script  and build the Standalone using the Compile or Package button. Advanced users can use command line compilation. (Note if you need run several MATLAB scripts from, say, a perl file or shall, then all these MATLAB script should be included)
Save the obtained tool installation package, and if you have another PC without MATLAB try to install and run there. If you have not, try in a container or virtual PC.

TIP 1 If you use MATLAB compiler from GUI, save your settings in a project file
TIP 2 Please keep in mind that not every MATLAB script can be compiled, read how write compilable scripts

            
           
                   https://blogs.mathworks.com/loren/2008/06/19/writing-deployable-code/
           TIP 3 While container created with installation package usually is smaller, it is not as convenient as having a base container with all the required modules and prerequisites and build the tool container above it
# III CONTAINERIZE 
Make sure you have a docker or singularity preferable with privileged access. If not use a virtual machine environment (e.g VirtualBox).
If you unfamiliar with containers, read singularity and/or docker tutorial to get idea how containers are created and used such as https://singularity.lbl.gov/quickstart, 
Check few examples of CBRAIN tools such as qEEG or BEst containers 
https://github.com/MontrealSergiy/BEst/blob/master/Singularity.1
Build container recipes and images. To have a smaller image, generate an install package with compiler,  installation package from your computer or some online storage (ftp, google drive, github release), and install it and any required packages. Alternatively you can rely on Matlab docker building functionality or build upon an existing image with matlab runtime.
Test that you can run tool in the container (preferably in a VM to make sure that it can run on any machine, and not only yours)
Upload container image or recipe to a repository such as DockerHub or Singularity Hub (or just email it to us)
Note, there are other scenarios, Matlab supports building docker automatically from GUI or command line.

# IV FORMALIZE COMMAND LINE
Document command line, arguments, defaults, constraints, using a table or English language. You can group similar parameters. 
Provide a demo data and command line. 
Build the JSON Boutiques description of all the command line, all the parameters, and some constraints such as mutually exclusive parameters etc. Refer to https://boutiques.github.io/ for full info. An interactive tutorial is on https://mybinder.org/v2/gh/boutiques/tutorial/master?filepath=notebooks/boutiques-tutorial.ipynb.
Install ‘bosh’ (by running pip instal boutiques) to validate and test the descriptor or use the above binder notebook.
If you have difficulties with creating valid JSON try JSON spy, https://jsondraft.com/ or https://json-editor.github.io/json-editor/ (for the latter you should enter the boutiques schema)
Put the JSON Boutiques descripot on the github repo and share the address with the CBRAIN team. Follow folder structure as in https://github.com/big-data-lab-team/CBRAIN-plugins-eeg
The boutiques package can run pipelines. Try to run your pipeline with boutiques. In any case we can test it and if everything is ok will deploy. The web interface is built automatically from the JSON file description    

V OTHER BEST PRACTICES
       The tool should support relative paths at least for output files/folders (results). Learn1 more about best path practices in the following  Matlab blog

       Path management https://blogs.mathworks.com/loren/2008/08/11/path-management-in-deployed-applications/

If you facing any issues with this or need help, do not hesitate to consult with CBRAIN team
