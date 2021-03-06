#!/usr/bin/env bash



export TWINE_REPOSITORY="https://test.pypi.org"
condalabel="test"










echo "=============================================================="
echo "BASH_VERSION" $BASH_VERSION
echo $(git --version)
tagname="$(git describe --abbrev=0 --tags)"
tag="$(git rev-list $tagname | head -n 1)"
com="$(git rev-parse HEAD)"
dirty=$(git describe --tags --dirty --always)
msg=$(git log -1 --pretty=%B)
echo "=============================================================="
echo "Establish git variables:"
echo "=============================================================="
echo "Current commit hash : $com"
echo "Dirty tag           : $dirty"
echo "Commit msg          : $msg"
echo "=============================================================="
echo "Environment variables:"
echo "=============================================================="
echo "CI                   = $CI"
echo "APPVEYOR             = $APPVEYOR"
echo "CIRCLECI             = $CIRCLECI"
echo "TRAVIS               = $TRAVIS"
echo "CODESHIP             = $CI_NAME"
echo "=============================================================="
echo "Build information:"
echo "=============================================================="
if [[ "$com" = "$tag" ]]&&[[ $dirty = $tagname ]]
then
    echo "Tagged commit      : $tagname"
    PEP440="^([1-9]\d*!)?(0|[1-9]\d*)(\.(0|[1-9]\d*))*((a|b|rc)(0|[1-9]\d*))?(\.post(0|[1-9]\d*))?(\.dev(0|[1-9]\d*))?$"
    if [[ $tagname =~  $PEP440 ]]
    then
        echo "Git tag is a canonical PEP440 release version number"
        echo "deploy a setuptools package to pypi."
        echo "deploy conda packages to anaconda.org under the BjornFJohansson channel"
    else
        echo "Git tag is *NOT* a canonical PEP440 release version number"
        echo "git tag ($tagname) was not recognized"
        echo "or"
        echo "$dirty != $tagname"
        exit 0
    fi
elif [[ $msg = *"skip"* ]]
then
    echo "'skip' found in commit msg: '$msg'"
    echo "tests and builds skipped."
    echo "=============================================================="
    exit 0 
else
    echo "'skip' not found in commit msg: '$msg'"
    echo "but commit not tagged or tag dirty"
    echo "test suit will be run."
    tagged_commit=false

unset VIRTUAL_ENV
fi











if [[ $CI = true ]]||[[ $CI = True ]]
then
    echo "====================Running on CI server======================"
    [[ ! -z "$TWINE_USERNAME" ]] && echo "TWINE_USERNAME is set" || echo "TWINE_USERNAME is empty"
    [[ ! -z "$TWINE_PASSWORD" ]] && echo "TWINE_PASSWORD is set" || echo "TWINE_PASSWORD is empty"
    [[ ! -z "$ANACONDATOKEN" ]]  && echo "ANACONDATOKEN is set"  || echo "ANACONDATOKEN is empty"
    if [[ $TRAVIS = true ]]
    then
        echo "Running on TRAVIS, download Miniconda for MacOSX"
        miniconda="wget -q http://repo.continuum.io/miniconda/Miniconda3-latest-MacOSX-x86_64.sh -O Miniconda_latest.sh"
    elif [[ $APPVEYOR = true ]]||[[ $APPVEYOR = True ]]
    then
        echo "Running on APPVEYOR, use installed Miniconda for Windows"
        miniconda="source appveyor_source_file.sh"
    elif [[ $CIRCLECI = true ]]
    then
        miniconda="wget -q https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh -O Miniconda_latest.sh"
    elif [[ $CI_NAME = codeship ]]
    then
        miniconda="wget -q https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh -O Miniconda_latest.sh"
    else
        echo "Running on CI server but none of the expected environment variables are set to true"
        echo "CI       = $CI"
        echo "TRAVIS   = $TRAVIS"
        echo "APPVEYOR = $APPVEYOR"
        echo "CIRCLECI = $CIRCLECI"
        echo "CI_NAME  = $CI_NAME"
        exit 1
    fi
    echo "execute: $miniconda"
    $miniconda
    if [[ -f Miniconda_latest.sh ]]
    then
        bash Miniconda_latest.sh -b -p $HOME/miniconda
        export PATH="$HOME/miniconda/bin:$PATH"
        rm Miniconda_latest.sh
    fi
    conda config --set always_yes yes --set show_channel_urls yes
    #conda install conda-verify -yq
    #conda install jinja2 -yq
    conda update -yq conda
    conda update -yq pip
    conda config --append channels conda-forge 
    conda config --append channels BjornFJohansson
else
    echo "Not running on CI server, probably running on local computer"
    local_computer=true
fi





echo "====================create conda environments================="
set -x





conda env create -f python35.yml
conda env create -f python36.yml
conda env create -f python37.yml







if [[ $tagged_commit = true ]]
then
    echo "========build conda package and setuptools package(s)========="
    conda install -yq -c anaconda conda-build
    conda install -yq -c anaconda conda-verify
    echo "conda-build version used:"
    conda-build -V
    rm -rf dist
    rm -rf build
    rm -rf tests/htmlcov
    pth1="$(conda build . --output --py 3.5)"
    pth2="$(conda build . --output --py 3.6)"
    pth3="$(conda build . --output --py 3.7)"
    echo $pth1
    echo $pth2
    echo $pth3
    source activate python35
    conda build --python 3.5 --no-include-recipe --dirty .
    source activate python36
    conda build --python 3.6 --no-include-recipe --dirty .
    source activate python37
    conda build --python 3.7 --no-include-recipe --dirty .
    if [[ $CI = true ]]||[[ $CI = True ]]
    then
        set +x
        anaconda -t $ANACONDATOKEN upload $pth1 --label $condalabel --force
        anaconda -t $ANACONDATOKEN upload $pth2 --label $condalabel --force
        anaconda -t $ANACONDATOKEN upload $pth3 --label $condalabel --force
        set -x
    else
        anaconda upload $pth1 --label $condalabel --force
        anaconda upload $pth2 --label $condalabel --force
        anaconda upload $pth3 --label $condalabel --force
    fi

    if [[ $TRAVIS = true ]] # MacOSX on Travis
    then
        #brew update
        source activate python35
        python setup.py build bdist_wheel
        source activate python36
        python setup.py build bdist_wheel
        source activate python37
        python setup.py build bdist_wheel
    elif [[ $APPVEYOR = true ]]||[[ $APPVEYOR = True ]] # Windows on appveyor
    then
        source activate python35
        python setup.py build bdist_wheel 
        source activate python36
        python setup.py build bdist_wheel 
        source activate python37
        python setup.py build bdist_wheel
        appveyor PushArtifact dist/*        
    elif [[ $CI_NAME = codeship ]]  # Linux on codeship
    then
        source activate python35
        python setup.py build bdist_wheel 
        source activate python36
        python setup.py build bdist_wheel 
        source activate python37
        python setup.py build bdist_wheel 
        twine upload dist/pydna* --skip-existing
    elif [[ $local_computer = true ]]
    then
        echo "Local linux: python setup.py sdist --formats=zip bdist_wheel"
        source activate python35
        python setup.py build bdist_wheel 
        source activate python36
        python setup.py build bdist_wheel 
        source activate python37
        python setup.py build bdist_wheel 
        twine upload dist/pydna* --skip-existing
    else
        echo "Running on CI server but none of the expected environment variables are set to true"
        echo "CI       = $CI"
        echo "TRAVIS   = $TRAVIS"
        echo "APPVEYOR = $APPVEYOR"
        echo "CIRCLECI = $CIRCLECI"
        exit 1
    fi
else

    source activate python35
    python run_test.py
    source activate python36
    python run_test.py
    source activate python37
    python run_test.py
fi
