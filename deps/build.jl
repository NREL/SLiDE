abstract type AbstractOS end
abstract type Unix <: AbstractOS end
abstract type BSD <: Unix end

abstract type Windows <: AbstractOS end
abstract type MacOS <: BSD end
abstract type Linux <: BSD end

if Sys.iswindows()
    const os = Windows
elseif Sys.isapple()
    const os = MacOS
else
    const os = Linux
end

abstract type TestData end

function unzip(::Type{<:BSD}, filename, directory)
    @assert success(`tar -xvf $filename -C $directory`) "Unable to extract $filename to $directory"
end

function unzip(::Type{Windows}, filename, directory)
    path_7z = if Base.VERSION < v"0.7-"
        "$JULIA_HOME/7z"
    else
        sep = Sys.iswindows() ? ";" : ":"
        withenv(
            "PATH" => string(
                joinpath(Sys.BINDIR, "..", "libexec"),
                sep,
                Sys.BINDIR,
                sep,
                ENV["PATH"],
            ),
        ) do
            Sys.which("7z")
        end
    end
    @assert success(`$path_7z x $filename -y -o$directory`) "Unable to extract $filename to $directory"
end


"""
Download SLiDE Data from `branch="master"` name into a "data" folder in given argument path.
Skip the actual download if the folder already exists and force=false.
Defaults to the root of the PowerSystems package.

Returns the downloaded folder name.
"""
function Base.download(
    ::Type{TestData};
    folder::AbstractString = abspath(joinpath(@__DIR__, "..")),
    branch::String = "master",
    force::Bool = false,
)

    if Sys.iswindows()
        SLIDEDATA_URL = "https://github.com/NREL/SLiDEData/archive/$branch.zip"
    else
        SLIDEDATA_URL = "https://github.com/NREL/SLiDEData/archive/$branch.tar.gz"
    end
    directory = abspath(normpath(folder))
    data = joinpath(directory, "data")
    if !isdir(data) || force
        tempfilename = Base.download(SLIDEDATA_URL)
        mkpath(directory)
        unzip(os, tempfilename, directory)
        mv(joinpath(directory, "SLiDE-Data-$branch"), data, force = force)
    end

    return data
end

download(TestData; branch = "master")
