load("@rules_android//providers:providers.bzl", "StarlarkAndroidResourcesInfo")

def _path_relative_to_dir(file, directory):
    # Android assets are stored in the AAR under assets/<path relative to assets_dir>.
    # The provider gives us the logical assets_dir plus individual source/output files,
    # so package_aar has to stage each file at that AAR-relative path.
    if not directory:
        return file.basename

    normalized_dir = directory.strip("/")
    marker = normalized_dir + "/"
    if marker in file.path:
        return file.path.split(marker, 1)[1]

    if file.path == normalized_dir or file.path.endswith("/" + normalized_dir):
        return ""

    fail("Expected Android asset path '{}' to contain assets_dir '{}'".format(file.path, directory))

def _resource_file_aar_path(resource_file):
    if "/res/" in resource_file.path:
        return "res/" + resource_file.path.split("/res/", 1)[1]

    if resource_file.is_directory:
        return ""

    return "res/{}".format(resource_file.basename)

def _asset_aar_path(asset, assets_dir):
    rel = _path_relative_to_dir(asset, assets_dir)
    if rel:
        return "assets/{}".format(rel)

    return "assets"

def _collect_android_aar_entries(deps):
    entries = {}
    files = {}
    for dep in deps:
        if StarlarkAndroidResourcesInfo not in dep:
            continue

        resources_info = dep[StarlarkAndroidResourcesInfo]
        for node in resources_info.direct_resources_nodes.to_list():
            for asset in node.assets.to_list():
                dest = _asset_aar_path(asset, node.assets_dir)
                files["{}::{}".format(dest, asset.path)] = (asset, dest)

            for resource_file in node.resource_files.to_list():
                dest = _resource_file_aar_path(resource_file)
                files["{}::{}".format(dest, resource_file.path)] = (resource_file, dest)

    return [files[key] for key in sorted(files.keys())]

def _collect_assets_impl(ctx):
    all_assets = _collect_android_aar_entries(ctx.attr.deps)

    # Ensure we have at least one entry (package_aar expects a zip input).
    if not all_assets:
        empty = ctx.actions.declare_file("empty")
        ctx.actions.write(empty, "")
        all_assets.append((empty, "assets/empty"))

    out_zip = ctx.actions.declare_file("{}_assets.zip".format(ctx.label.name))
    scratch = ctx.actions.declare_directory("{}_assets_dir".format(ctx.label.name))

    script = ctx.actions.declare_file("{}_pack_assets.sh".format(ctx.label.name))
    ctx.actions.write(
        script,
        is_executable = True,
        content = """
set -euo pipefail
ITEMS=( {items} )
DEST='{dst}'

for item in "${{ITEMS[@]}}"; do
    src="${{item%%::*}}"
    rel="${{item#*::}}"
    out="$DEST/$rel"
    if [[ -d "$src" ]]; then
        mkdir -p "$out"
        cp -R "$src"/. "$out"/
    else
        mkdir -p "$(dirname "$out")"
        cp "$src" "$out"
    fi
    chmod -R u+w "$DEST"
done

ABS_DEST="$PWD/{zip}"
cd "$DEST" && zip -qqr "$ABS_DEST" .
""".format(
            items = " ".join(['"{}::{}"'.format(f.path, dest) for f, dest in all_assets]),
            dst = scratch.path,
            zip = out_zip.path,
        ),
    )

    ctx.actions.run_shell(
        inputs = depset([f for f, _ in all_assets]),
        tools = [script],
        outputs = [out_zip, scratch],
        command = script.path,
        progress_message = "Packaging Android AAR entries for %{label}",
    )

    return [DefaultInfo(files = depset([out_zip]))]

collect_android_assets = rule(
    implementation = _collect_assets_impl,
    attrs = {
        "deps": attr.label_list(
            mandatory = True,
            doc = "Android dependencies whose resources and assets should be packaged into the exported AAR.",
        ),
    },
    outputs = {"assets_zip": "%{name}_assets.zip"},
    doc = """Collects Android resources and assets from Android rule providers.

This includes Valdi .valdimodule files because valdi_module exposes them through
android_library assets, and it also includes ordinary android_library or
aar_import resources/assets without needing ValdiModuleInfo-specific traversal.
""",
)
