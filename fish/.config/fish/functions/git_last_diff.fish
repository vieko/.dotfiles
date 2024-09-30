function git_last_diff
    if test (count $argv) -eq 0
        echo "Usage: git_last_diff <file_path>"
        return 1
    end

    set file_path $argv[1]
    git log -1 --pretty=format:"%h - %an, %ar : %s" --patch -- $file_path
end
