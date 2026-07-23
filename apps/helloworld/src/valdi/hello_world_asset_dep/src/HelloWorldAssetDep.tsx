import res from '../res';
import { Component } from 'valdi_core/src/Component';

export class HelloWorldAssetDep extends Component<{}> {
  onRender(): void {
    <view>
      <image id="dependencyImage" src={res.dependencyBadge} width={32} height={32} />
    </view>;
  }
}
