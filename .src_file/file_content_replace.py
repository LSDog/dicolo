import os
import io
import sys

def list_allfile(path,all_files=[]) -> list[str]:    
    if os.path.exists(path):
        files=os.listdir(path)
    else:
        print('this path not exist')
    for file in files:
        if os.path.isdir(os.path.join(path,file)):
            list_allfile(os.path.join(path,file),all_files)
        else:
            all_files.append(os.path.join(path,file))
    return all_files

# 传入文件(file),将旧内容(old_content)替换为新内容(new_content)
def replace(file, replace_array: list):
    content = read_file(file)
    for replaces in replace_array:
        content = content.replace(replaces[0], replaces[1])
    rewrite_file(file, content)

# 读文件内容
def read_file(file):
    with open(file, encoding='UTF-8') as f:
        read_all = f.read()
        f.close()

    return read_all

# 写内容到文件
def rewrite_file(file, data):
    with open(file, 'w', encoding='UTF-8') as f:
        f.write(data)
        f.close()

def main():
    file_list = list_allfile(os.path.dirname(sys.argv[0]));
    print("涉及到的文件有这些...");
    print(file_list);
    action = input("回车确定, 其他键退出")
    if action != '':
        print("退出...")
        os._exit(0);
    print("执行中")
    # 替换操作
    for file_path in file_list:
        if not os.path.isfile(file_path):
            continue;
        file_name = os.path.basename(file_path);
        if file_name.startswith('map') & file_name.endswith('txt'):
            replace(
                file_path, [['levelname', 'mapname'], ['level', 'diff']]
            );
    print("完成！")

if __name__ == "__main__":
    sys.stdout=io.TextIOWrapper(sys.stdout.buffer,encoding='utf8');
    main();